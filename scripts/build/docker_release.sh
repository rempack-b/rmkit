OUTDIR=artifacts
TARGET=${TARGET:-rm}
mkdir ${OUTDIR}
docker run -i --rm -v "${PWD}/${OUTDIR}:/mnt/artifacts" rmkit /bin/bash << COMMANDS
mkdir -p src/build
TARGET=${TARGET} make
TARGET=${TARGET} make strip
TARGET=${TARGET} make bundle
mkdir -p /mnt/artifacts/${TARGET}/
mkdir -p /mnt/artifacts/src/
cp -r src/build/* /mnt/artifacts/${TARGET}/
cp -r src/.* /mnt/artifacts/src/
cp -r src/build/release.* /mnt/artifacts/${TARGET}/
chown -R $(id -u):$(id -u) /mnt/artifacts
COMMANDS
