{%- from "ceph/map.jinja" import common, cephfs with context %}

{%- if cephfs.get('enabled', False) %}

include:
- ceph.common

cephfs_packages:
  pkg.installed:
  - names: {{ cephfs.pkgs }}

cephfs_pool_metadata:
  cmd.run:
    - name: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool create {{ cephfs.get('name', 'cephfs') }}_{{ cephfs.metadata.pool }} {{ cephfs.metadata.pg_num }} replicated
    - unless: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool stats {{ cephfs.get('name', 'cephfs') }}_{{ cephfs.metadata.pool }}

cephfs_pool_root:
  cmd.run:
    - name: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool create {{ cephfs.get('name', 'cephfs') }}_{{ cephfs.root.pool }} {{ cephfs.root.pg_num }} {{ cephfs.root.get('type', 'erasure') }}
    - unless: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool stats {{ cephfs.get('name', 'cephfs') }}_{{ cephfs.root.pool }}

{%- if cephfs.root.get('type', 'erasure') == 'erasure' %}
cephfs_pool_root_overwrite:
  cmd.run:
    - name: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool set {{ cephfs.get('name', 'cephfs') }}_{{ cephfs.root.pool }} allow_ec_overwrites true
    - require_in:
      - cmd: cephfs_create_{{ cephfs.get('name', 'cephfs') }}
{%- endif %}

cephfs_create_{{ cephfs.get('name', 'cephfs') }}:
  cmd.run:
    - name: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf fs new {{ cephfs.get('name', 'cephfs') }} {{ cephfs.get('name', 'cephfs') }}_{{ cephfs.metadata.pool }} {{ cephfs.get('name', 'cephfs') }}_{{ cephfs.root.pool }}
    - unless: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf fs get {{ cephfs.get('name', 'cephfs') }}
    - require:
      - cmd: cephfs_pool_metadata
      - cmd: cephfs_pool_root

/etc/systemd/system/var-lib-ceph-cephfs-{{ common.get('cluster_name', 'ceph') }}-{{ cephfs.get('name', 'cephfs') }}.mount:
  file.managed:
    - source: salt://ceph/files/cephfs.mount
    - user: root
    - group: root
    - mode: 640
    - template: jinja

/var/lib/ceph/cephfs/{{ common.get('cluster_name', 'ceph') }}/{{ cephfs.get('name', 'cephfs') }}:
  file.directory:
    - user: ceph
    - group: ceph
    - mode: 700
    - makedirs: True

cephfs_mount:
  service.running:
    - name: var-lib-ceph-cephfs-{{ common.get('cluster_name', 'ceph') }}-{{ cephfs.get('name', 'cephfs') }}.mount
    - enable: True
    - requires:
      - file: /etc/systemd/system/var-lib-ceph-cephfs-{{ common.get('cluster_name', 'ceph') }}-{{ cephfs.get('name', 'cephfs') }}.mount
      - file: /var/lib/ceph/cephfs/{{ common.get('cluster_name', 'ceph') }}/{{ cephfs.get('name', 'cephfs') }}
      - cmd: cephfs_create_{{ cephfs.get('name', 'cephfs') }}

{%- for path, subpool in cephfs.get('subpools', {}).items() %}
cephfs_subpool_{{ subpool.pool }}_create:
  cmd.run:
    - name: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool create {{ cephfs.get('name', 'cephfs') }}_{{ subpool.pool }} {{ subpool.pg_num }} {{ subpool.get('type', 'erasure') }}
    - unless: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool stats {{ cephfs.get('name', 'cephfs') }}_{{ subpool.pool }}

{%- if subpool.get('type', 'erasure') == 'erasure' %}
cephfs_subpool_{{ subpool.pool }}_overwrites:
  cmd.run:
    - name: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool set {{ cephfs.get('name', 'cephfs') }}_{{ subpool.pool }} allow_ec_overwrites true
    - require_in:
      - cmd: cephfs_subpool_{{ subpool.pool }}_add
{%- endif %}

# Add subpool to MDS
cephfs_subpool_{{ subpool.pool }}_add:
  cmd.run:
    - name: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf fs add_data_pool {{ cephfs.get('name', 'cephfs') }} {{ cephfs.get('name', 'cephfs') }}_{{ subpool.pool }}
    - unless: "ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf fs ls |awk '/^name: {{ cephfs.get('name', 'cephfs') }},/ {print \\$5}' |grep {{ cephfs.get('name', 'cephfs') }}_{{ subpool.pool }}"
    - require:
      - cmd: cephfs_subpool_{{ subpool.pool }}_create

/var/lib/ceph/cephfs/{{ common.get('cluster_name', 'ceph') }}/{{ cephfs.get('name', 'cephfs') }}/{{ path }}:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: True

# Assign subpool to directory
cephfs_subpool_{{ subpool.pool }}_attr:
  cmd.run:
    - name: setfattr -n ceph.dir.layout.pool -v {{ cephfs.get('name', 'cephfs') }}_{{subpool.pool }} /var/lib/ceph/cephfs/{{ common.get('cluster_name', 'ceph') }}/{{ cephfs.get('name', 'cephfs') }}/{{ path }}
    - unless: getfattr -n ceph.dir.layout.pool /var/lib/ceph/cephfs/{{ common.get('cluster_name', 'ceph') }}/{{ cephfs.get('name', 'cephfs') }}/{{ path }} |grep {{ subpool.pool }}
    - require:
      - cmd: cephfs_subpool_{{ subpool.pool }}_add
      - service: cephfs_mount
      - file: /var/lib/ceph/cephfs/{{ common.get('cluster_name', 'ceph') }}/{{ cephfs.get('name', 'cephfs') }}/{{ path }}

{%- endfor %}
{%- endif %}
