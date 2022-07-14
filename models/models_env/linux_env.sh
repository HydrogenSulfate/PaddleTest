set +x;
pwd;

####ce框架根目录
rm -rf ce && mkdir ce;
cd ce;

export Repo=${Repo:-PaddleClas}
export Python_env=${Python_env:-path_way}
export Python_version=${Python_version:-37}
export CE_version=${CE_version:-V1}
export Priority_version=${Priority_version:-P0}
export Compile_version=${Compile_version:-https://paddle-qa.bj.bcebos.com/paddle-pipeline/Release-GpuAll-LinuxCentos-Gcc82-Cuda102-Trtoff-Py37-Compile/latest/paddlepaddle_gpu-0.0.0-cp37-cp37m-linux_x86_64.whl}
export Image_version=${Image_version:-registry.baidubce.com/paddlepaddle/paddle_manylinux_devel:cuda10.2-cudnn7}
export Data_path=${Data_path:-/ssd2/ce_data/PaddleClas}
export Project_path=${Project_path:-/workspace/task/PaddleClas}
export Common_name=${Common_name:-cls_common_release}  #CE框架中的执行步骤，名称各异所以需要传入
export model_flag=${model_flag:-CE}  #clas gan特有，可删除

####测试框架下载
if [[ ${CE_version} == "V2" ]];then
    export CE_version_name=continuous_evaluation
    wget -q ${CE_V2}
else
    export CE_version_name=Paddle_Cloud_CE
    wget -q ${CE_V1}
fi
ls
unzip -P ${CE_pass}  ${CE_version_name}.zip

####设置代理  proxy不单独配置 表示默认有全部配置，不用export
if  [[ ! -n "${http_proxy}" ]] ;then
    echo unset http_proxy
    export http_proxy=${http_proxy}
    export https_proxy=${http_proxy}
else
    export http_proxy=${http_proxy}
    export https_proxy=${http_proxy}
fi
export no_proxy=${no_proxy}
set -x;
ls;

####之前下载过了直接mv
if [[ -d "../task" ]];then
    mv ../task .  #task路径是CE框架写死的
else
    wget -q https://xly-devops.bj.bcebos.com/PaddleTest/PaddleTest.tar.gz --no-proxy  >/dev/null
    tar xf PaddleTest.tar.gz >/dev/null 2>&1
    mv PaddleTest task
fi

#通用变量[用户改]
test_code_download_path=./task/models/${Repo}/CE
test_code_download_path_CI=./task/models/${Repo}/CI
test_code_conf_path=./task/models/${Repo}/CE/conf  #各个repo自己管理，可以分类，根据任务类型copy对应的common配置

#迁移下载路径代码和配置到框架指定执行路径 [不用改]
mkdir -p ${test_code_download_path}/log
ls ${test_code_download_path}/log;
cp -r ./task/models/models_env/docker_run.sh  ./${CE_version_name}/src
cp -r ${test_code_download_path}/.  ./${CE_version_name}/src/task
cp -r ${test_code_download_path_CI}/.  ./${CE_version_name}/src/task
cp ${test_code_conf_path}/${Common_name}.py ./${CE_version_name}/src/task/common.py
cat ./${CE_version_name}/src/task/common.py;
ls;

####根据agent制定对应卡，记得起agent时文件夹按照release_01 02 03 04名称
tc_name=`(echo $PWD|awk -F '/' '{print $4}')`
echo "teamcity path:" $tc_name
if [ $tc_name == "release_02" ];then
    echo release_02
    sed -i "s/SET_CUDA = \"0\"/SET_CUDA = \"2\"/g"  ./${CE_version_name}/src/task/common.py
    sed -i "s/SET_MULTI_CUDA = \"0,1\"/SET_MULTI_CUDA = \"2,3\"/g" ./${CE_version_name}/src/task/common.py
    export SET_CUDA=2;
    export SET_MULTI_CUDA=2,3;

elif [ $tc_name == "release_03" ];then
    echo release_03
    sed -i "s/SET_CUDA = \"0\"/SET_CUDA = \"4\"/g"  ./${CE_version_name}/src/task/common.py
    sed -i "s/SET_MULTI_CUDA = \"0,1\"/SET_MULTI_CUDA = \"4,5\"/g" ./${CE_version_name}/src/task/common.py
    export SET_CUDA=4;
    export SET_MULTI_CUDA=4,5;

elif [ $tc_name == "release_04" ];then
    echo release_04
    sed -i "s/SET_CUDA = \"0\"/SET_CUDA = \"6\"/g"  ./${CE_version_name}/src/task/common.py
    sed -i "s/SET_MULTI_CUDA = \"0,1\"/SET_MULTI_CUDA = \"6,7\"/g"  ./${CE_version_name}/src/task/common.py
    export SET_CUDA=6;
    export SET_MULTI_CUDA=6,7;
else
    echo release_01
    export SET_CUDA=0;
    export SET_MULTI_CUDA=0,1;
fi

####显示执行步骤
cat ./${CE_version_name}/src/task/common.py

#####进入执行路径创建docker容器 [用户改docker创建]
cd ${CE_version_name}/src
ls;

if  [[ ! -n "${docker_flag}" ]] ;then
    ####创建docker
    set +x;
    docker_name="ce_${Repo}_${Priority_version}_${AGILE_JOB_BUILD_ID}" #AGILE_JOB_BUILD_ID以每个流水线粒度区分docker名称
    function docker_del()
    {
    echo "begin kill docker"
    docker rm -f ${docker_name}
    echo "end kill docker"
    }
    trap 'docker_del' SIGTERM
    nvidia-docker run -i   --rm \
                --name=${docker_name} --net=host \
                --shm-size=128G \
                -v $(pwd):/workspace \
                -v /ssd2:/ssd2 \
                -w /workspace \
                ${Image_version}  \
                /bin/bash -c "
                bash docker_run.sh;
    " &
    wait $!
    exit $?
else
    echo docker already build
    bash docker_run.sh
fi
