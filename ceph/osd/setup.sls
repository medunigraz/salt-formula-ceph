{%- from "ceph/map.jinja" import osd, common with context %}

ceph_osd_packages:
  pkg.installed:
  - names: {{ osd.pkgs }}

/etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf:
  file.managed:
  - source: salt://ceph/files/{{ common.version }}/ceph.conf.{{ grains.os_family }}
  - template: jinja
  - require:
    - pkg: ceph_osd_packages

{% set ceph_version = pillar.ceph.common.version %}

{%- if osd.volumes is defined %}

{%- for volume in osd.volumes %}

{%- if volume.get('enabled', True) %}

zap_volume_{{ volume.data }}:
  cmd.run:
  - name: "ceph-volume lvm zap {{ volume.data }}"
  - unless: "ceph-volume lvm list {{ volume.data }}"
  - require:
    - pkg: ceph_osd_packages
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf

{%- if volume.db is defined %}
zap_volume_{{ volume.data }}_db_{{ volume.db }}:
  cmd.run:
  - name: "ceph-volume lvm zap {{ volume.db }}"
  - unless: "ceph-volume lvm list {{ volume.db }}"
  - require:
    - pkg: ceph_osd_packages
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf
    - cmd: zap_volume_{{ volume.data }}
{%- endif %}

{%- if volume.wal is defined %}
zap_volume_{{ volume.data }}_wal_{{ volume.wal }}:
  cmd.run:
  - name: "ceph-volume lvm zap {{ volume.wal }}"
  - unless: "ceph-volume lvm list {{ volume.wal }}"
  - require:
    - pkg: ceph_osd_packages
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf
    - cmd: zap_volume_{{ volume.data }}
{%- endif %}

{%- set cmd = [] %}
{%- do cmd.append('--cluster ' + common.get('cluster_name', 'ceph')) %}
{%- if volume.db is defined %}
  {%- do cmd.append('--block.db ' + volume.db) %}
{%- endif %}
{%- if volume.wal is defined %}
  {%- do cmd.append('--block.wal ' + volume.wal) %}
{%- endif %}
{%- do cmd.append('--data ' + volume.data) %}

create_volume_{{ volume.data }}:
  cmd.run:
  - name: "ceph-volume lvm create --bluestore {{ cmd|join(' ') }}"
  - unless: "ceph-volume lvm list {{ volume.data }}"
  - require:
    - cmd: zap_volume_{{ volume.data }}
{%- if volume.db is defined %}
    - cmd: zap_volume_{{ volume.data }}_db_{{ volume.db }}
{%- endif %}
{%- if volume.wal is defined %}
    - cmd: zap_volume_{{ volume.data }}_wal_{{ volume.wal }}
{%- endif %}
    - pkg: ceph_osd_packages
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf
    - cmd: ceph_keyring_bootstrap-osd


{%- endif %}

{%- endfor %}

{%- endif %}

{%- if not grains.get('noservices') %}
osd_services_global:
  service.running:
  - enable: true
  - names: ['ceph-osd.target']
  - watch:
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf

osd_services:
  service.running:
  - enable: true
  - names: ['ceph.target']
  - watch:
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf
{%- endif %}
