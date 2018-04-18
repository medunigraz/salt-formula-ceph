{%- from "ceph/map.jinja" import common with context %}

common_packages:
  pkg.installed:
  - names: {{ common.pkgs }}

/etc/default/ceph:
  file.managed:
  - source: salt://ceph/files/env
  - template: jinja
  - require:
    - pkg: common_packages

/etc/ceph:
  file.directory:
  - user: root
  - group: root
  - mode: 755
  - makedirs: True

common_config:
  file.managed:
  - name: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf
  - source: salt://ceph/files/{{ common.version }}/ceph.conf.{{ grains.os_family }}
  - template: jinja
  - require:
    - pkg: common_packages
    - file: /etc/ceph

/etc/ceph/{{ common.get('cluster_name', 'ceph') }}.client.admin.keyring:
  file.managed:
  - source: salt://ceph/files/keyring
  - template: jinja
  - require:
    - pkg: common_packages
    - file: common_config

{%- if common.erasure_code_profiles is defined %}
{%- for name, options in common.erasure_code_profiles.items() %}
{%- if 'plugin' in options %}
erasure_code_profile_{{ name }}:
  cmd.run:
  - name: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd erasure-code-profile set {{ name }} {% for key, value in options.items() %}{{ key }}={{ value }}{% if not loop.last %} {% endif %}{% endfor %}
  - unless: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool erasure-code-profile get {{ name }}
  - require:
    - pkg: common_packages
    - file: common_config
{%- endif %}
{%- endfor %}
{%- endif %}
