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
    - name: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool create {{ cephfs.get('name', 'cephfs') }}_{{ cephfs.root.pool }} {{ cephfs.root.pg_num }} {{ cephfs.root.get('type', 'erasure') }}{%- if cephfs.root.profile is string %} {{ cephfs.root.profile }}{%- endif %}
    - unless: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool stats {{ cephfs.get('name', 'cephfs') }}_{{ cephfs.root.pool }}
{%- if cephfs.root.profile is string %}
    - require:
      - cmd: erasure_code_profile_{{ cephfs.root.profile }}
{%- endif %}

cephfs_pool_root_quota:
  cmd.run:
    - name: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool set-quota {{ cephfs.get('name', 'cephfs') }}_{{ cephfs.root.pool }} max_bytes {{ cephfs.root.get('quota', 0) }}
    - unless: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool get-quota {{ cephfs.get('name', 'cephfs') }}_{{ cephfs.root.pool }}
    - requires:
      - cmd: cephfs_pool_root

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

{% set cluster_unit = common.get('cluster_name', 'ceph') | regex_replace('[^A-Za-z0-9_\/]', '\\\\\\\\x2d') | regex_replace('/', '') | regex_replace('/', '-') %}
{% set fs_unit = cephfs.get('name', 'cephfs') | regex_replace('[^A-Za-z0-9_\/]', '\\\\\\\\x2d') | regex_replace('/', '') | regex_replace('/', '-') %}

/etc/systemd/system/var-lib-ceph-cephfs-{{ cluster_unit }}-{{ fs_unit }}.mount:
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
    - reload: False
    - requires:
      - file: /etc/systemd/system/var-lib-ceph-cephfs-{{ cluster_unit }}-{{ fs_unit }}.mount
      - file: /var/lib/ceph/cephfs/{{ common.get('cluster_name', 'ceph') }}/{{ cephfs.get('name', 'cephfs') }}
      - cmd: cephfs_create_{{ cephfs.get('name', 'cephfs') }}

{%- for subpool, config in cephfs.get('subpools', {}).items() %}
cephfs_subpool_{{ subpool }}_create:
  cmd.run:
    - name: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool create {{ cephfs.get('name', 'cephfs') }}_{{ subpool }} {{ config.pg_num }} {{ config.get('type', 'erasure') }}{%- if config.profile is string %} {{ config.profile }}{%- endif %}
    - unless: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool stats {{ cephfs.get('name', 'cephfs') }}_{{ subpool }}
{%- if config.profile is string %}
    - require:
      - cmd: erasure_code_profile_{{ config.profile }}
{%- endif %}

cephfs_subpool_{{ subpool }}_quota:
  cmd.run:
    - name: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool set-quota {{ cephfs.get('name', 'cephfs') }}_{{ subpool }} max_bytes {{ config.get('quota', 0) }}
    - unless: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool get-quota {{ cephfs.get('name', 'cephfs') }}_{{ subpool }}
    - requires:
      - cmd: cephfs_subpool_{{ subpool }}_create

{%- if config.get('type', 'erasure') == 'erasure' %}
cephfs_subpool_{{ subpool }}_overwrites:
  cmd.run:
    - name: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool set {{ cephfs.get('name', 'cephfs') }}_{{ subpool }} allow_ec_overwrites true
    - require_in:
      - cmd: cephfs_subpool_{{ subpool }}_add
{%- endif %}

# Add subpool to MDS
cephfs_subpool_{{ subpool }}_add:
  cmd.run:
    - name: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf fs add_data_pool {{ cephfs.get('name', 'cephfs') }} {{ cephfs.get('name', 'cephfs') }}_{{ subpool }}
    - unless: "ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf fs ls |awk '/^name: {{ cephfs.get('name', 'cephfs') }},/ {print \\$5}' |grep {{ cephfs.get('name', 'cephfs') }}_{{ subpool }}"
    - require:
      - cmd: cephfs_subpool_{{ subpool }}_create

{%- for path, config_path in config.get('paths').items() %}
# Create directory
/var/lib/ceph/cephfs/{{ common.get('cluster_name', 'ceph') }}/{{ cephfs.get('name', 'cephfs') }}/{{ path }}:
  file.directory:
    - user: {{ config_path.get('user', 'ceph') }}
    - group: {{ config_path.get('group', 'ceph') }}
    - mode: {{ config_path.get('mode', '0700') }}
    - makedirs: True
    - requires:
      - service: cephfs_mount

# Assign subpool to directory
cephfs_subpool_{{ path }}_attr:
  cmd.run:
    - name: setfattr -n ceph.dir.layout.pool -v {{ cephfs.get('name', 'cephfs') }}_{{ subpool }} /var/lib/ceph/cephfs/{{ common.get('cluster_name', 'ceph') }}/{{ cephfs.get('name', 'cephfs') }}/{{ path }}
    - unless: getfattr -n ceph.dir.layout.pool /var/lib/ceph/cephfs/{{ common.get('cluster_name', 'ceph') }}/{{ cephfs.get('name', 'cephfs') }}/{{ path }} |grep {{ subpool }}
    - require:
      - cmd: cephfs_subpool_{{ subpool }}_add
      - service: cephfs_mount
      - file: /var/lib/ceph/cephfs/{{ common.get('cluster_name', 'ceph') }}/{{ cephfs.get('name', 'cephfs') }}/{{ path }}
{%- endfor %}

{%- endfor %}
{%- endif %}
