{%- from "ceph/map.jinja" import common, mds with context %}

{%- if mds.get('enabled', False) %}

include:
- ceph.common

ceph_mds_packages:
  pkg.installed:
  - names: {{ mds.pkgs }}

/var/lib/ceph/mds/{{ common.get('cluster_name', 'ceph') }}-{{ grains.host }}/:
  file.directory:
  - template: jinja
  - user: ceph
  - group: ceph
  - require:
    - pkg: ceph_mds_packages

ceph_create_mds_keyring_{{ grains.host }}:
  cmd.run:
  - name: "ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf auth get-or-create mds.{{ grains.host }} mon 'allow rwx' osd 'allow *' mds 'allow *' mgr 'allow profile mds' -o /var/lib/ceph/mds/{{ common.get('cluster_name', 'ceph') }}-{{ grains.host }}/keyring"
  - unless: "test -f /var/lib/ceph/mds/{{ common.get('cluster_name', 'ceph') }}-{{ grains.host }}/keyring"
  - require:
    - file: /var/lib/ceph/mds/{{ common.get('cluster_name', 'ceph') }}-{{ grains.host }}/

{%- if not grains.get('noservices') %}
ceph-mds@{{ grains.host }}:
  service.running:
    - enable: true
    - watch:
      - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf
    - require:
      - pkg: ceph_mds_packages
      - cmd: ceph_create_mds_keyring_{{ grains.host }}
{%- endif %}


{%- endif %}
