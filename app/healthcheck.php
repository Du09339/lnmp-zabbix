<?php
declare(strict_types=1);

try {
    $pdo = new PDO(
        sprintf('mysql:host=%s;dbname=%s;charset=utf8mb4', getenv('DB_HOST'), getenv('DB_NAME')),
        getenv('DB_USER'),
        getenv('DB_PASSWORD'),
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    $pdo->query('SELECT message FROM site_messages WHERE id = 1')->fetchColumn();
    $redis = new Redis();
    $redis->connect((string) getenv('REDIS_HOST'), 6379, 1.5);
    $ping = $redis->ping();
    if ($ping !== true && $ping !== '+PONG') {
        exit(1);
    }
} catch (Throwable $error) {
    fwrite(STDERR, "Application dependencies are not healthy. Check container logs.\n");
    exit(1);
}
