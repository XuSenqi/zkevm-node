#/bin/bash

if [[ $# -ne 1 ]];then
    echo "eg. $0 start" >&2
    echo "eg. $0 stop" >&2
    exit 1
fi

node_path=/root/zkevm-node
deploy_dir=$node_path/deployment

action=$1
if [ "$action" == "stop" ];then
    cd $node_path/test
    make stop
    #cnt=$(ps aux | grep -i zkevm-node | awk 'NR>1{print p}{p=$0}' | wc -l)
    cnt=$(ps aux | grep -i zkevm-node | grep -v grep | wc -l)
    if [[ $cnt -gt 0 ]];then
        ps aux | grep -i zkevm-node | grep -v grep | awk '{print $2}' | xargs kill -9
    fi
    exit 0
fi

log_dir=$node_path/deployment/logs
mkdir -p $log_dir

cd $node_path
go install github.com/gobuffalo/packr/v2/packr2@v2.8.3
cd db/
packr2
cd ..
make build

cd test/
make stop
#cnt=$(ps aux | grep -i zkevm-node | awk 'NR>1{print p}{p=$0}' | wc -l)
cnt=$(ps aux | grep -i zkevm-node | grep -v grep | wc -l)
if [[ $cnt -gt 0 ]];then
    #ps aux | grep -i zkevm-node | awk 'NR>1{print p}{p=$0}' | awk '{print $2}' | xargs kill -9
    ps aux | grep -i zkevm-node | grep -v grep | awk '{print $2}' | xargs kill -9
fi

make run_basic

#approve
approve_dir=$node_path/deployment/approve_service
rm -rf $approve_dir
mkdir -p $approve_dir
cp $node_path/test/sequencer.keystore $approve_dir
cp $node_path/test/config/test.node.config.toml $approve_dir
sed -i 's/zkevm-mock-l1-network/localhost/g' $approve_dir/test.node.config.toml

$node_path/dist/zkevm-node approve --key-store-path $approve_dir/sequencer.keystore --pw testonly --am 115792089237316195423570985008687907853269984665640564039457584007913129639935 -y --cfg $approve_dir/test.node.config.toml


sleep 3
#zkevm-sync
sync_dir=$node_path/deployment/zkevm-sync_service
rm -rf $sync_dir
mkdir -p $sync_dir
cp $node_path/test/config/test.node.config.toml $sync_dir
cp $node_path/test/sequencer.keystore $sync_dir
cp $node_path/test/aggregator.keystore $sync_dir

sed -i 's/Host = \"zkevm-state-db\"/Host = "localhost"/g' $sync_dir/test.node.config.toml
sed -i 's/Host = \"zkevm-pool-db\"/Host = "localhost"/g' $sync_dir/test.node.config.toml
sed -i 's/Host = \"zkevm-event-db\"/Host = "localhost"/g' $sync_dir/test.node.config.toml

#先找到pool_db的行号n, n+2行替换,todo
fline=$(grep pool_db $sync_dir/test.node.config.toml -n |  awk -F ":" '{print $1}')
eline=$(($fline+2))
sed -i "${fline},${eline}s/Port = \"5432\"/Port = \"5433\"/" $sync_dir/test.node.config.toml

#先找到event_db的行号n, n+2行替换,todo
fline=$(grep event_db $sync_dir/test.node.config.toml -n |  awk -F ":" '{print $1}')
eline=$(($fline+2))
sed -i "${fline},${eline}s/Port = \"5432\"/Port = \"5435\"/" $sync_dir/test.node.config.toml

sed -i 's/zkevm-mock-l1-network/localhost/g' $sync_dir/test.node.config.toml
sed -i "s:/pk:${sync_dir}:g" $sync_dir/test.node.config.toml
sed -i 's/zkevm-prover:50061/localhost:50061/g' $sync_dir/test.node.config.toml
sed -i 's/zkevm-prover:50071/localhost:50071/g' $sync_dir/test.node.config.toml

# metrics 9091 --> 9089
# 9093:9089 # needed if metrics enabled
sed -i 's/Port = 9091/Port = 9089/g' $aggregator_dir/test.node.config.toml

sed -i 's/ProfilingPort = 6060/ProfilingPort = 6061/g' $sync_dir/test.node.config.toml

cp $node_path/test/config/test.genesis.config.json $sync_dir

ZKEVM_NODE_STATEDB_HOST=zkevm-state-db
nohup $node_path/dist/zkevm-node run --genesis $sync_dir/test.genesis.config.json --cfg $sync_dir/test.node.config.toml --components synchronizer > $log_dir/zkevm-sync.log &

sleep 2
#zkevm-eth-tx-manager
manager_dir=$node_path/deployment/zkevm-eth-tx-manager_service
rm -rf $manager_dir
mkdir -p $manager_dir
cp $node_path/test/sequencer.keystore $manager_dir
cp $node_path/test/aggregator.keystore $manager_dir
cp $node_path/test/config/test.node.config.toml $manager_dir

sed -i 's/Host = \"zkevm-state-db\"/Host = "localhost"/g' $manager_dir/test.node.config.toml
sed -i 's/Host = \"zkevm-pool-db\"/Host = "localhost"/g' $manager_dir/test.node.config.toml
sed -i 's/Host = \"zkevm-event-db\"/Host = "localhost"/g' $manager_dir/test.node.config.toml

#先找到pool_db的行号n, n+2行替换,todo
fline=$(grep pool_db $manager_dir/test.node.config.toml -n |  awk -F ":" '{print $1}')
eline=$(($fline+2))
sed -i "${fline},${eline}s/Port = \"5432\"/Port = \"5433\"/" $manager_dir/test.node.config.toml

#先找到event_db的行号n, n+2行替换,todo
fline=$(grep event_db $manager_dir/test.node.config.toml -n |  awk -F ":" '{print $1}')
eline=$(($fline+2))
sed -i "${fline},${eline}s/Port = \"5432\"/Port = \"5435\"/" $manager_dir/test.node.config.toml

# metrics 9091 --> 9094
# 9094:9091 # needed if metrics enabled
sed -i 's/Port = 9091/Port = 9094/g' $manager_dir/test.node.config.toml

sed -i 's/ProfilingPort = 6060/ProfilingPort = 9090/g' $manager_dir/test.node.config.toml

sed -i 's/zkevm-mock-l1-network/localhost/g' $manager_dir/test.node.config.toml
sed -i "s:/pk:${manager_dir}:g" $manager_dir/test.node.config.toml
sed -i 's/zkevm-prover:50061/localhost:50061/g' $manager_dir/test.node.config.toml
sed -i 's/zkevm-prover:50071/localhost:50071/g' $manager_dir/test.node.config.toml

cp $node_path/test/config/test.genesis.config.json $manager_dir

ZKEVM_NODE_STATEDB_HOST=zkevm-state-db
nohup $node_path/dist/zkevm-node run --genesis $manager_dir/test.genesis.config.json --cfg $manager_dir/test.node.config.toml --components eth-tx-manager > $log_dir/zkevm-eth-tx-manager.log &

# zkevm-sequencer
sequencer_dir=$node_path/deployment/zkevm-sequencer_service
rm -rf $sequencer_dir
mkdir -p $sequencer_dir
cp $node_path/test/sequencer.keystore $sequencer_dir
cp $node_path/test/config/test.node.config.toml $sequencer_dir
cp $node_path/test/config/test.genesis.config.json $sequencer_dir

sed -i 's/Host = \"zkevm-state-db\"/Host = "localhost"/g' $sequencer_dir/test.node.config.toml
sed -i 's/Host = \"zkevm-pool-db\"/Host = "localhost"/g' $sequencer_dir/test.node.config.toml
sed -i 's/Host = \"zkevm-event-db\"/Host = "localhost"/g' $sequencer_dir/test.node.config.toml

#先找到pool_db的行号n, n+2行替换,todo
fline=$(grep pool_db $sequencer_dir/test.node.config.toml -n |  awk -F ":" '{print $1}')
eline=$(($fline+2))
sed -i "${fline},${eline}s/Port = \"5432\"/Port = \"5433\"/" $sequencer_dir/test.node.config.toml

#先找到event_db的行号n, n+2行替换,todo
fline=$(grep event_db $sequencer_dir/test.node.config.toml -n |  awk -F ":" '{print $1}')
eline=$(($fline+2))
sed -i "${fline},${eline}s/Port = \"5432\"/Port = \"5435\"/" $sequencer_dir/test.node.config.toml

# metrics 9091 --> 9092
# 9092:9091 # needed if metrics enabled
sed -i 's/Port = 9091/Port = 9092/g' $sequencer_dir/test.node.config.toml

sed -i 's/zkevm-mock-l1-network/localhost/g' $sequencer_dir/test.node.config.toml
sed -i "s:/pk:${sequencer_dir}:g" $sequencer_dir/test.node.config.toml
sed -i 's/zkevm-prover:50061/localhost:50061/g' $sequencer_dir/test.node.config.toml
sed -i 's/zkevm-prover:50071/localhost:50071/g' $sequencer_dir/test.node.config.toml

ZKEVM_NODE_STATEDB_HOST=zkevm-state-db
ZKEVM_NODE_POOL_DB_HOST=zkevm-pool-db
ZKEVM_NODE_SEQUENCER_SENDER_ADDRESS=0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
#/app/zkevm-node run --genesis /app/genesis.json --cfg /app/config.toml --components sequencer
nohup $node_path/dist/zkevm-node run --genesis $sequencer_dir/test.genesis.config.json --cfg $sequencer_dir/test.node.config.toml --components sequencer > $log_dir/zkevm-sequencer.log &


# zkevm-l2gaspricer
l2gaspricer_dir=$node_path/deployment/zkevm-l2gaspricer_service
rm -rf $l2gaspricer_dir
mkdir -p $l2gaspricer_dir
cp $node_path/test/config/test.node.config.toml $l2gaspricer_dir
cp $node_path/test/config/test.genesis.config.json $l2gaspricer_dir

sed -i 's/Host = \"zkevm-state-db\"/Host = "localhost"/g' $l2gaspricer_dir/test.node.config.toml
sed -i 's/Host = \"zkevm-pool-db\"/Host = "localhost"/g' $l2gaspricer_dir/test.node.config.toml
sed -i 's/Host = \"zkevm-event-db\"/Host = "localhost"/g' $l2gaspricer_dir/test.node.config.toml

#先找到pool_db的行号n, n+2行替换,todo
fline=$(grep pool_db $l2gaspricer_dir/test.node.config.toml -n |  awk -F ":" '{print $1}')
eline=$(($fline+2))
sed -i "${fline},${eline}s/Port = \"5432\"/Port = \"5433\"/" $l2gaspricer_dir/test.node.config.toml

#先找到event_db的行号n, n+2行替换,todo
fline=$(grep event_db $l2gaspricer_dir/test.node.config.toml -n |  awk -F ":" '{print $1}')
eline=$(($fline+2))
sed -i "${fline},${eline}s/Port = \"5432\"/Port = \"5435\"/" $l2gaspricer_dir/test.node.config.toml

# metrics 9091 --> 9095
# 9095:9091 # needed if metrics enabled
sed -i 's/Port = 9091/Port = 9095/g' $l2gaspricer_dir/test.node.config.toml

sed -i 's/zkevm-mock-l1-network/localhost/g' $l2gaspricer_dir/test.node.config.toml
sed -i "s:/pk:${l2gaspricer_dir}:g" $l2gaspricer_dir/test.node.config.toml
sed -i 's/zkevm-prover:50061/localhost:50061/g' $l2gaspricer_dir/test.node.config.toml
sed -i 's/zkevm-prover:50071/localhost:50071/g' $l2gaspricer_dir/test.node.config.toml

sed -i 's/ProfilingPort = 6060/ProfilingPort = 6065/g' $l2gaspricer_dir/test.node.config.toml

ZKEVM_NODE_POOL_DB_HOST=zkevm-pool-db
#/app/zkevm-node run --genesis /app/genesis.json --cfg /app/config.toml --components l2gaspricer
nohup $node_path/dist/zkevm-node run --genesis $l2gaspricer_dir/test.genesis.config.json --cfg $l2gaspricer_dir/test.node.config.toml --components l2gaspricer > $log_dir/zkevm-l2gaspricer.log &

## zkevm-aggregator
#aggregator_dir=$node_path/deployment/zkevm-aggregator_service
#rm -rf $aggregator_dir
#mkdir -p $aggregator_dir
#cp $node_path/test/config/test.node.config.toml $aggregator_dir
#cp $node_path/test/config/test.genesis.config.json $aggregator_dir
#
#sed -i 's/Host = \"zkevm-state-db\"/Host = "localhost"/g' $aggregator_dir/test.node.config.toml
#sed -i 's/Host = \"zkevm-pool-db\"/Host = "localhost"/g' $aggregator_dir/test.node.config.toml
#sed -i 's/Host = \"zkevm-event-db\"/Host = "localhost"/g' $aggregator_dir/test.node.config.toml
#
##先找到pool_db的行号n, n+2行替换,todo
#fline=$(grep pool_db $aggregator_dir/test.node.config.toml -n |  awk -F ":" '{print $1}')
#eline=$(($fline+2))
#sed -i "${fline},${eline}s/Port = \"5432\"/Port = \"5433\"/" $aggregator_dir/test.node.config.toml
#
##先找到event_db的行号n, n+2行替换,todo
#fline=$(grep event_db $aggregator_dir/test.node.config.toml -n |  awk -F ":" '{print $1}')
#eline=$(($fline+2))
#sed -i "${fline},${eline}s/Port = \"5432\"/Port = \"5435\"/" $aggregator_dir/test.node.config.toml
#
## metrics 9091 --> 9093
## 9093:9091 # needed if metrics enabled
#sed -i 's/Port = 9091/Port = 9093/g' $aggregator_dir/test.node.config.toml
#
#sed -i 's/zkevm-mock-l1-network/localhost/g' $aggregator_dir/test.node.config.toml
#sed -i "s:/pk:${aggregator_dir}:g" $aggregator_dir/test.node.config.toml
#sed -i 's/zkevm-prover:50061/localhost:50061/g' $aggregator_dir/test.node.config.toml
#sed -i 's/zkevm-prover:50071/localhost:50071/g' $aggregator_dir/test.node.config.toml
#
#sed -i 's/ProfilingPort = 6060/ProfilingPort = 6063/g' $aggregator_dir/test.node.config.toml
#
#ZKEVM_NODE_STATEDB_HOST=zkevm-state-db
#ZKEVM_NODE_AGGREGATOR_SENDER_ADDRESS=0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
##/app/zkevm-node run --genesis /app/genesis.json --cfg /app/config.toml --components aggregator
#nohup $node_path/dist/zkevm-node run --genesis $aggregator_dir/test.genesis.config.json --cfg $aggregator_dir/test.node.config.toml --components aggregator > $log_dir/zkevm-aggregator.log &

make run_aggregator


# zkevm-json-rpc
rpc_dir=$node_path/deployment/rpc_service
rm -rf $rpc_dir
mkdir -p $rpc_dir
cp $node_path/test/config/test.node.config.toml $rpc_dir
cp $node_path/test/config/test.genesis.config.json $rpc_dir

sed -i 's/Host = \"zkevm-state-db\"/Host = "localhost"/g' $rpc_dir/test.node.config.toml
sed -i 's/Host = \"zkevm-pool-db\"/Host = "localhost"/g' $rpc_dir/test.node.config.toml
sed -i 's/Host = \"zkevm-event-db\"/Host = "localhost"/g' $rpc_dir/test.node.config.toml

#先找到pool_db的行号n, n+2行替换
fline=$(grep pool_db $rpc_dir/test.node.config.toml -n |  awk -F ":" '{print $1}')
eline=$(($fline+2))
sed -i "${fline},${eline}s/Port = \"5432\"/Port = \"5433\"/" $rpc_dir/test.node.config.toml

#先找到event_db的行号n, n+2行替换
fline=$(grep event_db $rpc_dir/test.node.config.toml -n |  awk -F ":" '{print $1}')
eline=$(($fline+2))
sed -i "${fline},${eline}s/Port = \"5432\"/Port = \"5435\"/" $rpc_dir/test.node.config.toml

# metrics 9091 --> 9093
# 9093:9091 # needed if metrics enabled
sed -i 's/Port = 9091/Port = 9099/g' $rpc_dir/test.node.config.toml

sed -i 's/zkevm-mock-l1-network/localhost/g' $rpc_dir/test.node.config.toml
sed -i "s:/pk:${rpc_dir}:g" $rpc_dir/test.node.config.toml
sed -i 's/zkevm-prover:50061/localhost:50061/g' $rpc_dir/test.node.config.toml
sed -i 's/zkevm-prover:50071/localhost:50071/g' $rpc_dir/test.node.config.toml

sed -i 's/ProfilingPort = 6060/ProfilingPort = 6069/g' $rpc_dir/test.node.config.toml

ZKEVM_NODE_STATEDB_HOST=zkevm-state-db
ZKEVM_NODE_POOL_DB_HOST=zkevm-pool-db
#/app/zkevm-node run --genesis /app/genesis.json --cfg /app/config.toml --components rpc
nohup $node_path/dist/zkevm-node run --genesis $rpc_dir/test.genesis.config.json --cfg $rpc_dir/test.node.config.toml --components rpc > $log_dir/zkevm-json-rpc.log &



