<?php
declare(strict_types=1);

function respond(int $status, array $payload): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function database(): PDO
{
    return new PDO(
        sprintf('mysql:host=%s;dbname=%s;charset=utf8mb4', getenv('DB_HOST'), getenv('DB_NAME')),
        getenv('DB_USER'),
        getenv('DB_PASSWORD'),
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );
}

function cache(): Redis
{
    $redis = new Redis();
    $redis->connect((string) getenv('REDIS_HOST'), 6379, 1.5);
    return $redis;
}

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
if ($path === '/healthz') {
    $checks = ['mysql' => false, 'redis' => false];
    try {
        database()->query('SELECT 1');
        $checks['mysql'] = true;
    } catch (Throwable $error) {
        error_log('MySQL health check failed: ' . $error->getMessage());
    }
    try {
        $ping = cache()->ping();
        $checks['redis'] = $ping === true || $ping === '+PONG';
    } catch (Throwable $error) {
        error_log('Redis health check failed: ' . $error->getMessage());
    }
    $healthy = !in_array(false, $checks, true);
    respond($healthy ? 200 : 503, ['status' => $healthy ? 'ok' : 'degraded', 'checks' => $checks]);
}

try {
    $redis = cache();
    $cached = $redis->get('lnmp:announcement:v1');
    $cacheHit = $cached !== false;
    if (!$cacheHit) {
        $statement = database()->query('SELECT message FROM site_messages WHERE id = 1');
        $cached = (string) ($statement->fetchColumn() ?: 'No announcement has been configured.');
        $redis->setex('lnmp:announcement:v1', 30, $cached);
    }
} catch (Throwable $error) {
    error_log('Application request failed: ' . $error->getMessage());
    respond(503, ['status' => 'unavailable', 'message' => 'A required service is unavailable. Check the service logs.']);
}

header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: no-store');
$safeMessage = htmlspecialchars((string) $cached, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
$cacheLabel = $cacheHit ? 'HIT' : 'MISS';
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>LNMP Operations Lab</title>
    <link rel="stylesheet" href="/assets/site.css">
</head>
<body>
<main>
    <p class="eyebrow">DOCKER COMPOSE / PHP-FPM / MYSQL / REDIS</p>
    <h1>LNMP Operations Lab</h1>
    <p class="message"><?= $safeMessage ?></p>
    <dl>
        <div><dt>Database</dt><dd>MySQL 8.4</dd></div>
        <div><dt>Cache</dt><dd>Redis 7.4</dd></div>
        <div><dt>Current request</dt><dd>Redis <?= $cacheLabel ?></dd></div>
        <div><dt>Health endpoint</dt><dd><a href="/healthz">/healthz</a></dd></div>
    </dl>
</main>
</body>
</html>
