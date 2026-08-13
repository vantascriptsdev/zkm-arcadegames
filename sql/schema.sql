CREATE TABLE IF NOT EXISTS `zkm_arcade_machines` (
    `id`         VARCHAR(16)  NOT NULL,
    `game`       VARCHAR(16)  NOT NULL,
    `x`          DOUBLE       NOT NULL,
    `y`          DOUBLE       NOT NULL,
    `z`          DOUBLE       NOT NULL,
    `heading`    FLOAT        NOT NULL,
    `created_by` VARCHAR(64)  NOT NULL DEFAULT '',
    `created_at` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- You do NOT need to run this script. It is automatically being loaded & executed during runtime (server/modules/admin.lua)