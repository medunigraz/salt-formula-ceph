{%- from "ceph/map.jinja" import common with context %}

{% for name, keyring in common.get('keyring', {}).items() %}

ceph_create_keyring_{{ name }}:
  cmd.run:
  - name: "ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf auth get-or-create client.{{ name }} {%- for cap_name, cap in  keyring.caps.items() %} {{ cap_name }} '{{ cap }}' {%- endfor %} -o /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.client.{{ name }}.keyring"
  - unless: "test -f /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.client.{{ name }}.keyring"

{% endfor %}
