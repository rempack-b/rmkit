OUTDIR=artifacts
PACKAGE="${1}"
TARGET=${TARGET:-rm}
mkdir ${OUTDIR}
docker run -i --rm -v "${PWD}/${OUTDIR}:/mnt/artifacts" rmkit /bin/bash << COMMANDS
mkdir -p src/build
TARGET=${TARGET} make ${PACKAGE}
mkdir -p /mnt/artifacts/${TARGET}/
mkdir -p /mnt/artifacts/src/
cp -r src/build/* /mnt/artifacts/${TARGET}/
cp -r src/.* /mnt/artifacts/src/
chown -R $(id -u):$(id -u) /mnt/artifacts
COMMANDS

