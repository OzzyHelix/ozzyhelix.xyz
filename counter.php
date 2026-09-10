<?php
// 1990s-style visitor counter for ozzyhelix.xyz.
// Stores the count in data/counter.txt and renders it as an odometer-style SVG image.
//
// Usage:
//   <img src="counter.php" alt="visitors">          render odometer (increments count)
//   counter.php?view=1                              render odometer without incrementing
//   counter.php?raw=1                               plain zero-padded number, no increment
//   counter.php?reset=1                             reset count to 0
//   counter.php?set=1234                            set count to a value
//
// Serve through nginx + PHP-FPM (see nginx.conf.example and deploy/setup-debian.sh).

$dataDir = __DIR__ . '/data';
$counterFile = $dataDir . '/counter.txt';
$digits = 7;

function getCount($fp) {
    fseek($fp, 0);
    $n = (int) stream_get_contents($fp);
    return max(0, $n);
}

function writeCount($fp, $n) {
    ftruncate($fp, 0);
    fseek($fp, 0);
    fwrite($fp, (string) $n);
    fflush($fp);
}

if (!is_dir($dataDir)) {
    mkdir($dataDir, 0775, true);
}

$fp = fopen($counterFile, 'c+');
if (!$fp) {
    http_response_code(500);
    header('Content-Type: text/plain');
    echo 'counter unavailable';
    exit;
}

flock($fp, LOCK_EX);
$raw   = isset($_GET['raw']) && $_GET['raw'] !== '0';
$view  = isset($_GET['view']) && $_GET['view'] !== '0';
$reset = isset($_GET['reset']) && $_GET['reset'] !== '0';
$set   = isset($_GET['set']) ? (int) $_GET['set'] : -1;

if ($reset) {
    writeCount($fp, 0);
} elseif ($set >= 0) {
    writeCount($fp, $set);
} elseif (!$view && !$raw) {
    writeCount($fp, getCount($fp) + 1);
}

$count = getCount($fp);
flock($fp, LOCK_UN);
fclose($fp);

$formatted = str_pad((string) $count, $digits, '0', STR_PAD_LEFT);

if ($raw) {
    header('Content-Type: text/plain');
    header('Cache-Control: no-store, no-cache, must-revalidate');
    header('Pragma: no-cache');
    header('X-Accel-Expires: 0');
    echo $formatted;
    exit;
}

// --- Odometer-style SVG render ---

$cellW = 34;          // width of one digit slot
$cellH = 44;          // height of one digit slot
$gap   = 3;           // gap between slots
$pad   = 12;          // outer frame padding
$gapY  = 20;          // top strip height (holds the label)

$odomW = $digits * $cellW + ($digits - 1) * $gap;
$width = $odomW + $pad * 2;
$height = $pad * 2 + $gapY + $cellH;
$labelY = $pad + 14;
$odomTop = $pad + $gapY;

header('Content-Type: image/svg+xml');
header('Cache-Control: no-store, no-cache, must-revalidate');
header('Pragma: no-cache');
header('X-Accel-Expires: 0');

echo '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
?>
<svg xmlns="http://www.w3.org/2000/svg" width="<?php echo $width; ?>" height="<?php echo $height; ?>" role="img" aria-label="Visitor count <?php echo $formatted; ?>">
  <!-- frame -->
  <rect x="1" y="1" width="<?php echo $width - 2; ?>" height="<?php echo $height - 2; ?>" rx="5" fill="#0e0e14" stroke="#2a2a3a" stroke-width="2"/>
  <!-- label -->
  <text x="<?php echo $width / 2; ?>" y="<?php echo $labelY; ?>" text-anchor="middle" font-family="'Courier New', monospace" font-size="11" letter-spacing="3" fill="#9a9ab0">visitors</text>
  <!-- odometer body -->
  <rect x="<?php echo $pad; ?>" y="<?php echo $odomTop; ?>" width="<?php echo $odomW; ?>" height="<?php echo $cellH; ?>" rx="3" fill="#000000" stroke="#444457" stroke-width="1"/>
<?php
for ($i = 0; $i < $digits; $i++) {
    $x = $pad + $i * ($cellW + $gap);
    $d = substr($formatted, $i, 1);
?>
  <!-- <?php echo $i; ?> -->
  <rect x="<?php echo $x; ?>" y="<?php echo $odomTop + 2; ?>" width="<?php echo $cellW - 1; ?>" height="<?php echo $cellH - 4; ?>" rx="2" fill="#030306" stroke="#22222f" stroke-width="1"/>
  <text x="<?php echo $x + ($cellW - 1) / 2; ?>" y="<?php echo $odomTop + $cellH - 8; ?>" text-anchor="middle" font-family="'Courier New', monospace" font-weight="bold" font-size="30" fill="#e8e8f2"><?php echo $d; ?></text>
<?php } ?>
</svg>