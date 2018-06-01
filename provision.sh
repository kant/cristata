#!/bin/bash
#Author: Mark Purcell

bx_creds=./temp-cred.json


function db2 {
    bx service create 'dashDB' 'Entry' cristata-db2
    bx service key-create cristata-db2 credentials
    bx service key-show cristata-db2 credentials > $bx_creds
    sed -i -e '1,4d' $bx_creds

    jdbc=`cat $bx_creds | jq '.ssljdbcurl' | tr -d '"'`
    temp=`echo $jdbc | cut -f3 -d':'`
    url="https:$temp/dashdb-api/v2"
    user=`cat $bx_creds | jq '.username' | tr -d '"'`
    schema=${user^^}
    password=`cat $bx_creds | jq '.password' | tr -d '"'`

    echo 'export DB2_SCHEMA='$user > $1
    echo 'export DB2_PARAMS="--param database_userid' $user '--param database_password' $password '--param database_rest_url' $url'"' >> $1

    cmd='java -cp sql/target/sql-deploy-0.1.1.jar ibm.drl.sqldeploy.Execute'
    $cmd $jdbc $user $password $schema
}

function iot {
    bx service create iotf-service iotf-service-free cristata-iot
    bx service key-create cristata-iot credentials
    bx service key-show cristata-iot credentials > $bx_creds
    sed -i -e '1,4d' $bx_creds

    key=`cat $bx_creds | jq '.apiKey' | tr -d '"'`
    token=`cat $bx_creds | jq '.apiToken' | tr -d '"'`
    iotorg=`cat $bx_creds | jq '.org' | tr -d '"'`

    #Create devices and credentials for MQTT
    ./iot/setup.sh $key $token $iotorg ./mqtt-config1.json ./mqtt-config2.json
}

function mhub {
    bx service create messagehub standard cristata-mhub
    bx service key-create cristata-mhub credentials
    bx service key-show cristata-mhub credentials > $bx_creds
    sed -i -e '1,4d' $bx_creds

    key=`cat $bx_creds | jq '.api_key' | sed -e 's/.*"\(.*\)".*/\1/'`
    url=`cat $bx_creds | jq '.kafka_admin_url' | sed -e 's/.*"\(.*\)".*/\1/'`

    cd mhub
    python3 admin.py --url $url --api_key $key --topic watson-iot
    cd ..
}

command -v jq >/dev/null 2>&1 || { echo >&2 "Error - package jq required, but not available."; exit 1; }

db2 openwhisk/my_setup.sh
iot 
mhub

rm $bx_creds


