CREATE TABLE IF NOT EXISTS site_messages (
    id TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    message VARCHAR(255) NOT NULL
);

INSERT IGNORE INTO site_messages (id, message)
VALUES (1, 'The application is reading this message from MySQL through Redis cache.');
