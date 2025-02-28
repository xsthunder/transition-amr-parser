#!/bin/bash

set -o errexit
set -o pipefail
# . set_environment.sh
set -o nounset


##### CONFIG
dir=$(dirname $0)
# if [ ! -z "${1+x}" ]; then
if [ ! -z "$1" ]; then
    config=$1
    . $dir/$config    # we should always call from one level up
fi
# NOTE: when the first configuration argument is not provided, this script must
#       be called from other scripts


##### script specific config
if [ -z "$2" ]; then
    data_split_amr="dev"
else
    data_split_amr=$2
fi

if [ $data_split_amr == "dev" ]; then
    data_split=valid
    reference_amr=$AMR_DEV_FILE
    wiki=$WIKI_DEV
    reference_amr_wiki=$AMR_DEV_FILE_WIKI
elif [ $data_split_amr == "test" ]; then
    data_split=test
    reference_amr=$AMR_TEST_FILE
    wiki=$WIKI_TEST
    reference_amr_wiki=$AMR_TEST_FILE_WIKI
else
    echo "$2 is invalid; must be dev or test"
fi
    

# data_split=valid
# data_split_amr=dev    # TODO make the names consistent
# reference_amr=$AMR_DEV_FILE

# data_split=test
# data_split_amr=test    # TODO make the names consistent
# reference_amr=$AMR_TEST_FILE

model_epoch=${model_epoch:-_last}
beam_size=${beam_size:-10}
batch_size=${batch_size:-128}

RESULTS_FOLDER=$MODEL_FOLDER/beam${beam_size}
# results_prefix=$RESULTS_FOLDER/${data_split}_checkpoint${model_epoch}.nopos-score
results_prefix=$RESULTS_FOLDER/${data_split}_checkpoint${model_epoch}
model=$MODEL_FOLDER/checkpoint${model_epoch}.pt


# ##### DECODING
# # rm -Rf $RESULTS_FOLDER
# mkdir -p $RESULTS_FOLDER
# # --nbest 3 \
# # --quiet
# python fairseq_ext/generate.py \
#     $DATA_FOLDER  \
#     --emb-dir $EMB_FOLDER \
#     --user-dir ../fairseq_ext \
#     --task amr_action_pointer \
#     --gen-subset $data_split \
#     --machine-type AMR  \
#     --machine-rules $ORACLE_FOLDER/train.rules.json \
#     --beam $beam_size \
#     --batch-size $batch_size \
#     --remove-bpe \
#     --path $model  \
#     --quiet \
#     --results-path $results_prefix \

# # exit 0

##### post-processing after decoding
# python scripts_tp/clean_pointer_arcs.py \
#     $results_prefix
    
    
# ##### Create the AMR from the model obtained actions
# python transition_amr_parser/o7_fake_parse.py \
#     --in-sentences $ORACLE_FOLDER/$data_split_amr.en \
#     --in-actions $results_prefix.carc.actions \
#     --out-amr $results_prefix.carc.amr \

# exit 0

##### SMATCH evaluation
if [[ "$wiki" == "" ]]; then

    # Smatch evaluation without wiki
    
    echo "Computing SMATCH ---"
    python smatch/smatch.py \
         --significant 4  \
         -f $reference_amr \
         $results_prefix.carc.amr \
         -r 10 \
         > $results_prefix.carc.smatch

    cat $results_prefix.carc.smatch

else

    # Smatch evaluation with wiki

    # add wiki
    echo "Add wiki ---"
    python scripts/add_wiki.py \
        $results_prefix.carc.amr $wiki \
        > $results_prefix.carc.wiki.amr

    # compute score
    echo "Computing SMATCH ---"
    python smatch/smatch.py \
         --significant 4  \
         -f $reference_amr_wiki \
         $results_prefix.carc.wiki.amr \
         -r 10 \
         > $results_prefix.carc.wiki.smatch

    cat $results_prefix.carc.wiki.smatch

fi

