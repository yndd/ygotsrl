#!/bin/bash

go install github.com/openconfig/ygot/generator@v0.20.0
git clone -b $1 --single-branch https://github.com/nokia/srlinux-yang-models.git nokia > /dev/null 2>&1
rm -f nokia/srlinux-yang-models/srl_nokia/models/*/*tools*.yang

generator -output_file=ygotsrl.go \
    -logtostderr \
    -path=nokia/srlinux-yang-models \
    -package_name=ygotsrl -generate_fakeroot -fakeroot_name=device -compress_paths=false \
    -shorten_enum_leaf_names \
    -typedef_enum_with_defmod \
    -enum_suffix_for_simple_union_enums \
    -generate_rename \
    -generate_append \
    -generate_getters \
    -generate_delete \
    -generate_simple_unions \
    -generate_populate_defaults \
    -include_schema \
    -exclude_state \
    -yangpresence \
    -include_model_data \
    -generate_leaf_getters \
    nokia/srlinux-yang-models/srl_nokia/models/*/*.yang

rm -rf nokia/
