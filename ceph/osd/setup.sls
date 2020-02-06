{%- from "ceph/map.jinja" import osd, common with context %}

ceph_osd_packages:
  pkg.installed:
  - names: {{ osd.pkgs }}

ceph_create_keyring_bootstrap-osd:
  cmd.run:
  - name: "ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf auth get-or-create client.bootstrap-osd mon 'allow profile bootstrap-osd' > /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.client.bootstrap-osd.keyring"
  - unless: "test -f /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.client.boostrap-osd.keyring"

ceph_import_keyring_bootstrap-osd:
  cmd.wait:
    - name: "ceph-authtool --create-keyring /var/lib/ceph/bootstrap-osd/{{ common.get('cluster_name', 'ceph') }}.keyring --import-keyring /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.client.bootstrap-osd.keyring"
    - watch:
      - cmd: ceph_create_keyring_bootstrap-osd

{% set ceph_version = pillar.ceph.common.version %}

{%- if osd.get('volumes', []) is iterable %}

{%- for volume in osd.volumes %}

{%- if volume.get('enabled', True) %}

ceph_zap_volume_{{ volume.data }}:
  cmd.run:
  - name: "ceph-volume --cluster {{ common.get('cluster_name', 'ceph') }} lvm zap {{ volume.data }} || true"
  - unless: "ceph-volume --cluster {{ common.get('cluster_name', 'ceph') }} lvm list {{ volume.data }}"
  - require:
    - pkg: ceph_osd_packages
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf

{%- if volume.db is defined %}
ceph_zap_volume_{{ volume.data }}_db_{{ volume.db }}:
  cmd.run:
  - name: "ceph-volume --cluster {{ common.get('cluster_name', 'ceph') }} lvm zap {{ volume.db }} || true"
  - unless: "ceph-volume --cluster {{ common.get('cluster_name', 'ceph') }} lvm list {{ volume.db }}"
  - require:
    - pkg: ceph_osd_packages
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf
    - cmd: ceph_zap_volume_{{ volume.data }}
{%- endif %}

{%- if volume.wal is defined %}
ceph_zap_volume_{{ volume.data }}_wal_{{ volume.wal }}:
  cmd.run:
  - name: "ceph-volume --cluster {{ common.get('cluster_name', 'ceph') }} lvm zap {{ volume.wal }} || true"
  - unless: "ceph-volume --cluster {{ common.get('cluster_name', 'ceph') }} lvm list {{ volume.wal }}"
  - require:
    - pkg: ceph_osd_packages
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf
    - cmd: ceph_zap_volume_{{ volume.data }}
{%- endif %}

{%- set cmd = [] %}
{%- if volume.db is defined %}
  {%- do cmd.append('--block.db ' + volume.db) %}
{%- endif %}
{%- if volume.wal is defined %}
  {%- do cmd.append('--block.wal ' + volume.wal) %}
{%- endif %}
{%- do cmd.append('--data ' + volume.data) %}

ceph_create_volume_{{ volume.data }}:
  cmd.run:
  - name: "ceph-volume --cluster {{ common.get('cluster_name', 'ceph') }} lvm create --bluestore {{ cmd|join(' ') }}"
  - unless: "ceph-volume --cluster {{ common.get('cluster_name', 'ceph') }} lvm list {{ volume.data }}"
  - require:
    - cmd: ceph_zap_volume_{{ volume.data }}
{%- if volume.db is defined %}
    - cmd: ceph_zap_volume_{{ volume.data }}_db_{{ volume.db }}
{%- endif %}
{%- if volume.wal is defined %}
    - cmd: ceph_zap_volume_{{ volume.data }}_wal_{{ volume.wal }}
{%- endif %}
    - pkg: ceph_osd_packages
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf
    - cmd: ceph_import_keyring_bootstrap-osd

{%- endif %}

{%- endfor %}

{%- endif %}

{%- if not grains.get('noservices') %}
ceph_osd_services_global:
  service.running:
  - enable: true
  - names: ['ceph-osd.target']
  - watch:
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf

ceph_osd_services:
  service.running:
  - enable: true
  - names: ['ceph.target']
  - watch:
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf
{%- endif %}
