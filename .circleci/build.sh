#!/usr/bin/env bash

echo "Cloning dependencies"
git clone --depth=1 https://github.com/fskhri/kernel-xiaomi-surya -b sbv6 kernel
cd kernel
git clone --depth=1 https://github.com/llvm/llvm-project llvm
git clone --depth=1 https://github.com/fskhri/AnyKernel3 -b ribka AnyKernel
git clone --depth=1 https://android.googlesource.com/platform/system/libufdt libufdt
echo "Done"

IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
TANGGAL=$(date +"%F-%S")
LOG=$(echo *.log)
START=$(date +"%s")

export CONFIG_PATH=$PWD/arch/arm64/configs/surya-perf_defconfig
TC_DIR=${PWD}
LLVM_DIR="${PWD}/llvm"
PATH="${LLVM_DIR}/bin:/usr/bin:$PATH"

export ARCH=arm64
export KBUILD_BUILD_HOST="LuLu"
export KBUILD_BUILD_USER="Ribka"
export CLANG_TRIPLE=aarch64-linux-gnu-

# sticker plox
function sticker() {
    curl -s -X POST "https://api.telegram.org/bot$BOTTOKEN/sendSticker" \
        -d sticker="CAADBQADVAADaEQ4KS3kDsr-OWAUFgQ" \
        -d chat_id=$CHATID
}

# Send info plox channel
function sendinfo() {
    curl -s -X POST "https://api.telegram.org/bot$BOTTOKEN/sendMessage" \
        -d chat_id="$CHATID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="<b>• surya-Stormbreaker Kernel •</b>%0ABuild started on <code>Circle CI</code>%0AFor device <b>Poco X3</b> (picasso)%0Abranch <code>$(git rev-parse --abbrev-ref HEAD)</code>(master)%0AUnder commit <code>$(git log --pretty=format:'"%h : %s"' -1)</code>%0AUsing compiler: <code>Clang</code>%0AStarted on <code>$(date)</code>%0A<b>Build Status:</b> #AOSP-Alpha"
}

# Push kernel to channel
function push() {
    cd AnyKernel
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$BOTTOKEN/sendDocument" \
        -F chat_id="$CHATID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For <b>Poco X3 (surya)</b> | <b>Eva Clang</b>"
}

# Fin Error
function finerr() {
    curl -F document=@$LOG "https://api.telegram.org/bot$BOTTOKEN/sendDocument" \
        -F chat_id="$CHATID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build logs"
}

# Compile plox
function compile() {
    make O=out ARCH=arm64 surya-perf_defconfig
    make -j$(nproc --all) O=out \
                          ARCH=arm64 \
                          CC=clang \
                          CLANG_TRIPLE=aarch64-linux-gnu- \
                          CROSS_COMPILE=aarch64-linux-gnu- \
                          CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                          AR=llvm-ar \
                          OBJDUMP=llvm-objdump \
                          STRIP=llvm-strip 2>&1 | tee error.log
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel
    python2 "libufdt/utils/src/mkdtboimg.py" \
            create "out/arch/arm64/boot/dtbo.img" --page_size=4096 out/arch/arm64/boot/dts/qcom/*.dtbo
    cp out/arch/arm64/boot/dtbo.img AnyKernel
}

# Zipping
function zipping() {
    cd AnyKernel || exit 1
    zip -r9 surya-Stormbreaker-${TANGGAL}.zip *
    cd ..
}

sticker
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
finerr
push
