{%- if pillar.ceph is defined %}
include:
{% if pillar.ceph.common is defined %}
- ceph.common
- ceph.setup.keyring
{% endif %}
{% if pillar.ceph.backup is defined %}
- ceph.backup
{% endif %}
{% if pillar.ceph.mon is defined %}
- ceph.mon
{% endif %}
{% if pillar.ceph.mgr is defined %}
- ceph.mgr
{% endif %}
{% if pillar.ceph.mds is defined %}
- ceph.mds
{% endif %}
{% if pillar.ceph.cephfs is defined %}
- ceph.cephfs
{% endif %}
{% if pillar.ceph.osd is defined %}
- ceph.osd
{% endif %}
{% if pillar.ceph.setup is defined %}
- ceph.setup
{% endif %}
{% if pillar.ceph.client is defined %}
- ceph.client
{% endif %}
{% if pillar.ceph.radosgw is defined %}
- ceph.radosgw
{% endif %}
{%- endif %}
