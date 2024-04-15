#!/bin/bash

start=$(date +%s)

# Detect the number of NVIDIA GPUs and create a device string
gpu_count=$(nvidia-smi -L | wc -l)
if [ $gpu_count -eq 0 ]; then
    echo "No NVIDIA GPUs detected. Exiting."
    exit 1
fi
# Construct the CUDA device string
cuda_devices=""
for ((i=0; i<gpu_count; i++)); do
    if [ $i -gt 0 ]; then
        cuda_devices+=","
    fi
    cuda_devices+="$i"
done

# Install dependencies
apt update
apt install -y screen vim git-lfs
screen

export AWS_ACCESS_KEY_ID="$ARCEE_AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$ARCEE_AWS_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION=us-east-2

echo "aws key:" "$AWS_ACCESS_KEY_ID"

# Install common libraries
pip install -q requests accelerate sentencepiece pytablewriter einops protobuf

if [ "$DEBUG" == "True" ]; then
    echo "Launch LLM AutoEval in debug mode"
fi

# Run evaluation
if [ "$BENCHMARK" == "nous" ]; then
    git clone -b add-agieval https://github.com/dmahan93/lm-evaluation-harness
    cd lm-evaluation-harness
    pip install -e .

    benchmark="agieval"
    python main.py \
        --model hf-causal \
        --model_args pretrained=$MODEL_ID,trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks agieval_aqua_rat,agieval_logiqa_en,agieval_lsat_ar,agieval_lsat_lr,agieval_lsat_rc,agieval_sat_en,agieval_sat_en_without_passage,agieval_sat_math \
        --device cuda:$cuda_devices \
        --batch_size auto \
        --output_path ./${benchmark}.json

    benchmark="gpt4all"
    python main.py \
        --model hf-causal \
        --model_args pretrained=$MODEL_ID,trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks hellaswag,openbookqa,winogrande,arc_easy,arc_challenge,boolq,piqa \
        --device cuda:$cuda_devices \
        --batch_size auto \
        --output_path ./${benchmark}.json

    benchmark="truthfulqa"
    python main.py \
        --model hf-causal \
        --model_args pretrained=$MODEL_ID,trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks truthfulqa_mc \
        --device cuda:$cuda_devices \
        --batch_size auto \
        --output_path ./${benchmark}.json

    benchmark="bigbench"
    python main.py \
        --model hf-causal \
        --model_args pretrained=$MODEL_ID,trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks bigbench_causal_judgement,bigbench_date_understanding,bigbench_disambiguation_qa,bigbench_geometric_shapes,bigbench_logical_deduction_five_objects,bigbench_logical_deduction_seven_objects,bigbench_logical_deduction_three_objects,bigbench_movie_recommendation,bigbench_navigate,bigbench_reasoning_about_colored_objects,bigbench_ruin_names,bigbench_salient_translation_error_detection,bigbench_snarks,bigbench_sports_understanding,bigbench_temporal_sequences,bigbench_tracking_shuffled_objects_five_objects,bigbench_tracking_shuffled_objects_seven_objects,bigbench_tracking_shuffled_objects_three_objects \
        --device cuda:$cuda_devices \
        --batch_size auto \
        --output_path ./${benchmark}.json

    end=$(date +%s)
    echo "Elapsed Time: $(($end-$start)) seconds"
    
    python ../llm-autoeval/main.py . $(($end-$start))

elif [ "$BENCHMARK" == "openllm" ]; then
    git clone https://github.com/EleutherAI/lm-evaluation-harness
    cd lm-evaluation-harness
    python -m pip install --upgrade pip
    pip install -e .
    pip install --upgrade vllm
    pip install langdetect immutabledict

    benchmark="arc"
    lm_eval --model vllm \
        --model_args pretrained=${MODEL_ID},trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks arc_challenge \
        --num_fewshot 25 \
        --batch_size auto \
        --output_path ./${benchmark}.json

    benchmark="hellaswag"
    lm_eval --model vllm \
        --model_args pretrained=${MODEL_ID},trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks hellaswag \
        --num_fewshot 10 \
        --batch_size auto \
        --output_path ./${benchmark}.json

    # benchmark="mmlu"
    # lm_eval --model hf \
    #     --model_args pretrained=${MODEL_ID},trust_remote_code=$TRUST_REMOTE_CODE \
    #     --tasks mmlu \
    #     --num_fewshot 5 \
    #     --batch_size auto \
    #     --verbosity DEBUG \
    #     --output_path ./${benchmark}.json
    
    benchmark="truthfulqa"
    lm_eval --model vllm \
        --model_args pretrained=${MODEL_ID},trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks truthfulqa \
        --num_fewshot 0 \
        --batch_size auto \
        --output_path ./${benchmark}.json
    
    benchmark="winogrande"
    lm_eval --model vllm \
        --model_args pretrained=${MODEL_ID},trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks winogrande \
        --num_fewshot 5 \
        --batch_size auto \
        --output_path ./${benchmark}.json
    
    benchmark="gsm8k"
    lm_eval --model vllm \
        --model_args pretrained=${MODEL_ID},trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks gsm8k \
        --num_fewshot 5 \
        --batch_size auto \
        --output_path ./${benchmark}.json

    end=$(date +%s)
    echo "Elapsed Time: $(($end-$start)) seconds"
    
    python ../llm-autoeval/main.py . $(($end-$start))

elif [ "$BENCHMARK" == "medqa" ]; then
    git clone https://github.com/EleutherAI/lm-evaluation-harness
    cd lm-evaluation-harness
    python -m pip install --upgrade pip
    pip install -e .
    pip install --upgrade vllm
    pip install langdetect immutabledict

    benchmark="medqa"
    lm_eval --model vllm \
        --model_args pretrained=${MODEL_ID},trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks medqa_4options \
        --num_fewshot 0 \
        --batch_size auto \
        --output_path ./${benchmark}.json


    end=$(date +%s)
    echo "Elapsed Time: $(($end-$start)) seconds"
    
    python ../llm-autoeval/main.py . $(($end-$start))

elif [ "$BENCHMARK" == "medmcqa" ]; then
    git clone https://github.com/EleutherAI/lm-evaluation-harness
    cd lm-evaluation-harness
    python -m pip install --upgrade pip
    pip install -e .
    pip install --upgrade vllm
    pip install langdetect immutabledict

    benchmark="medmcqa"
    lm_eval --model vllm \
        --model_args pretrained=${MODEL_ID},trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks medmcqa \
        --num_fewshot 0 \
        --batch_size auto \
        --output_path ./${benchmark}.json


    end=$(date +%s)
    echo "Elapsed Time: $(($end-$start)) seconds"
    
    python ../llm-autoeval/main.py . $(($end-$start))

elif [ "$BENCHMARK" == "pubmedqa" ]; then
    git clone https://github.com/EleutherAI/lm-evaluation-harness
    cd lm-evaluation-harness
    python -m pip install --upgrade pip
    pip install -e .
    pip install --upgrade vllm
    pip install langdetect immutabledict

    benchmark="pubmedqa"
    lm_eval --model vllm \
        --model_args pretrained=${MODEL_ID},trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks pubmedqa \
        --num_fewshot 0 \
        --batch_size auto \
        --output_path ./${benchmark}.json


    end=$(date +%s)
    echo "Elapsed Time: $(($end-$start)) seconds"
    
    python ../llm-autoeval/main.py . $(($end-$start))

elif [ "$BENCHMARK" == "legalbench" ]; then
    git clone https://github.com/EleutherAI/lm-evaluation-harness
    git clone https://github.com/Malikeh97/llm-autoeval.git
    cp -r llm-autoeval/tasks/* lm-evaluation-harness/lm_eval/tasks/
    
    cd lm-evaluation-harness
    pip install -e .
    pip install accelerate

    benchmark="legalbench_issue_tasks" 
    echo "================== $(echo $benchmark | tr '[:lower:]' '[:upper:]') [1/6] =================="
    accelerate launch -m lm_eval \
        --model hf \
        --model_args pretrained=${MODEL_ID},dtype=auto,trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks legalbench_issue_tasks \
        --num_fewshot 0 \
        --batch_size auto \
        --output_path ./${benchmark}.json

    benchmark="legalbench_rule_tasks" 
    echo "================== $(echo $benchmark | tr '[:lower:]' '[:upper:]') [1/6] =================="
    accelerate launch -m lm_eval \
        --model hf \
        --model_args pretrained=${MODEL_ID},dtype=auto,trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks legalbench_rule_tasks \
        --num_fewshot 0 \
        --batch_size auto \
        --output_path ./${benchmark}.json

    benchmark="legalbench_conclusion_tasks" 
    echo "================== $(echo $benchmark | tr '[:lower:]' '[:upper:]') [1/6] =================="
    accelerate launch -m lm_eval \
        --model hf \
        --model_args pretrained=${MODEL_ID},dtype=auto,trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks legalbench_conclusion_tasks \
        --num_fewshot 0 \
        --batch_size auto \
        --output_path ./${benchmark}.json

    benchmark="legalbench_interpretation_tasks" 
    echo "================== $(echo $benchmark | tr '[:lower:]' '[:upper:]') [1/6] =================="
    accelerate launch -m lm_eval \
        --model hf \
        --model_args pretrained=${MODEL_ID},dtype=auto,trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks legalbench_interpretation_tasks \
        --num_fewshot 0 \
        --batch_size auto \
        --output_path ./${benchmark}.json

    benchmark="legalbench_rhetoric_tasks" 
    echo "================== $(echo $benchmark | tr '[:lower:]' '[:upper:]') [1/6] =================="
    accelerate launch -m lm_eval \
        --model hf \
        --model_args pretrained=${MODEL_ID},dtype=auto,trust_remote_code=$TRUST_REMOTE_CODE \
        --tasks legalbench_rhetoric_tasks \
        --num_fewshot 0 \
        --batch_size auto \
        --output_path ./${benchmark}.json

    end=$(date +%s)
    echo "Elapsed Time: $(($end-$start)) seconds"
    
    python ../llm-autoeval/main.py . $(($end-$start))


else
    pip install -U "huggingface_hub[cli]"
    huggingface-cli login --token "$HF_TOKEN"

    # git clone https://github.com/arcee-ai/arcee-eval.git
    git clone https://github.com/EleutherAI/lm-evaluation-harness
    # TODO: move to reqs
    pip install boto3
    pip install rouge_score
    pip install datasets
    #echo "lm-evaluation-harness/lm_eval/tasks/"
    #ls -l lm-evaluation-harness/lm_eval/tasks/

    cd llm-autoeval
    SCRIPT_DIR="$(pwd)"
    echo "Current dir:" "$SCRIPT_DIR"
    ls -l
    python llm_autoeval/download.py --task "${BENCHMARK}" --out_dir "${SCRIPT_DIR}"
    # shellcheck disable=SC2103
    cd ..
    cp -r llm-autoeval/tasks/* lm-evaluation-harness/lm_eval/tasks/

    cd lm-evaluation-harness
    python -m pip install --upgrade pip
    pip install -e .
    echo "USE_VLLM =" "$USE_VLLM"
    echo "tensor_parallel_size =" "$TENSOR_PARALLEL_SIZE"
    echo "data_parallel_size =" "$DATA_PARALLEL_SIZE"
    echo "PARALLELIZE =" "$PARALLELLIZE"
    echo "DTYPE =" "${DTYPE}"
    echo "BATCH_SIZE =" "${BATCH_SIZE}"

    if [ "$USE_VLLM" == "True" ]; then
      pip install --upgrade vllm
      pip install langdetect immutabledict
      echo "Running vllm eval"
      lm_eval --model vllm \
          --verbosity DEBUG \
          --model_args pretrained=${MODEL_ID},dtype=${DTYPE},trust_remote_code=$TRUST_REMOTE_CODE,tensor_parallel_size=${TENSOR_PARALLEL_SIZE},data_parallel_size=${DATA_PARALLEL_SIZE} \
          --tasks ${BENCHMARK} \
          --num_fewshot ${NUM_FEWSHOT} \
          --batch_size ${BATCH_SIZE} \
          --output_path ./${BENCHMARK}.json
    else
      echo "Running HF eval"
      ls -l
      lm_eval --verbosity DEBUG --model hf \
          --model_args pretrained=${MODEL_ID},dtype=${DTYPE},trust_remote_code=$TRUST_REMOTE_CODE,parallelize=${PARALLELLIZE} \
          --tasks ${BENCHMARK} \
          --num_fewshot ${NUM_FEWSHOT} \
          --batch_size ${BATCH_SIZE} \
          --output_path ./${BENCHMARK}.json
    fi
    end=$(date +%s)
    echo "Elapsed Time: $(($end-$start)) seconds"
    cat ./${BENCHMARK}.json
    python ../llm-autoeval/main.py . $(($end-$start))
    #echo "Error: Invalid BENCHMARK value. Please set BENCHMARK to 'nous' or 'openllm'."
fi

if [ "$DEBUG" == "False" ]; then
    runpodctl remove pod $RUNPOD_POD_ID
fi
sleep infinity
