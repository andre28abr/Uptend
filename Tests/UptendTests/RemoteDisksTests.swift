import Testing
@testable import Uptend

/// Parsers de discos — fixtures reais capturadas do uptend-lab.
struct RemoteDisksTests {

    @Test func parsesLsblkAndFilters() {
        let out = """
        NAME="nbd0" SIZE="0" TYPE="disk" MOUNTPOINT="" FSTYPE=""
        NAME="vda" SIZE="415649792" TYPE="disk" MOUNTPOINT="" FSTYPE=""
        NAME="vdb" SIZE="994663481856" TYPE="disk" MOUNTPOINT="" FSTYPE=""
        NAME="vdb1" SIZE="994662416384" TYPE="part" MOUNTPOINT="/mnt/machines/uptend-lab" FSTYPE="btrfs"
        NAME="vdc" SIZE="1073741824" TYPE="disk" MOUNTPOINT="[SWAP]" FSTYPE="swap"
        """
        let devs = RemoteDisks.parseLsblk(out)
        // nbd0 (size 0) é filtrado
        #expect(devs.map(\.name) == ["vda", "vdb", "vdb1", "vdc"])
        let vdb1 = devs.first { $0.name == "vdb1" }
        #expect(vdb1?.type == "part")
        #expect(vdb1?.fstype == "btrfs")
        #expect(vdb1?.mount == "/mnt/machines/uptend-lab")
        #expect(devs.first { $0.name == "vdb" }?.isDisk == true)
    }

    @Test func parsesDfDedupAndFiltersPseudo() {
        let out = """
        Filesystem     Type        1B-blocks         Used        Avail Use% Mounted on
        /dev/vdb1      btrfs    598146760704  17267822592 580878938112   3% /
        /dev/vdb1      btrfs    598146760704  17267822592 580878938112   3% /opt/orbstack-guest/data
        tmpfs          tmpfs      4194304000            0   4194304000   0% /run
        mac            virtiofs 994662584320 382607314944 612055269376  39% /mnt/mac
        """
        let u = RemoteDisks.parseDf(out)
        // /dev/vdb1 aparece 1x (dedupe), tmpfs filtrado, mac (virtiofs) fica
        #expect(u.count == 2)
        let mac = u.first { $0.source == "mac" }
        #expect(mac?.mount == "/mnt/mac")
        #expect(abs((mac?.usedFraction ?? 0) - 0.3846) < 0.001)
        // ordenado por uso desc → mac (39%) antes de vdb1 (3%)
        #expect(u.first?.source == "mac")
    }

    @Test func summarizesRaid() {
        #expect(RemoteDisks.summarizeRaid("Personalities :\n---ZFS---\nno-zfs").contains("nenhum array"))
        #expect(RemoteDisks.summarizeRaid("md0 : active raid1 sda[0]\n---ZFS---\nno-zfs").contains("detectado"))
        #expect(RemoteDisks.summarizeRaid("Personalities :\n---ZFS---\n  pool: tank").contains("pool(s) detectado"))
    }
}
