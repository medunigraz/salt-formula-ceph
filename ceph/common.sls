{%- from "ceph/map.jinja" import common with context %}

ceph_common_packages:
  pkg.installed:
  - names: {{ common.pkgs }}

/etc/default/ceph:
  file.managed:
  - source: salt://ceph/files/env
  - template: jinja

/etc/ceph:
  file.directory:
  - user: root
  - group: root
  - mode: 755
  - makedirs: True

/etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf:
  file.managed:
  - source: salt://ceph/files/{{ common.version }}/ceph.conf.{{ grains.os_family }}
  - template: jinja
  - require:
    - file: /etc/ceph

/etc/ceph/{{ common.get('cluster_name', 'ceph') }}.client.admin.keyring:
  file.managed:
  - source: salt://ceph/files/keyring
  - template: jinja
  - require:
    - file: /etc/ceph
