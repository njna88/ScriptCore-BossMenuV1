-- ##########################################################################
-- ScriptCore.dk - Boss Menu Database Layout
-- ##########################################################################
-- VIGTIGT:
-- Denne SQL opretter KUN bossmenuens egne tabeller/society-konti.
-- Den sletter eller indsætter IKKE politi/brand/ambulance/viking/autoexotic rangs.
-- Scriptet bruger de rangs, du allerede har i din ESX `job_grades` tabel.
-- ##########################################################################

CREATE TABLE IF NOT EXISTS `scriptcore_boss_transactions` (
    `id` INT(11) AUTO_INCREMENT PRIMARY KEY,
    `job_name` VARCHAR(50) DEFAULT NULL,
    `type` VARCHAR(20) DEFAULT NULL,
    `amount` INT(11) DEFAULT 0,
    `player_name` VARCHAR(100) DEFAULT 'Ukendt',
    `player_id` VARCHAR(100) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `scriptcore_boss_logs` (
    `id` INT(11) AUTO_INCREMENT PRIMARY KEY,
    `job_name` VARCHAR(50) DEFAULT NULL,
    `action` VARCHAR(50) DEFAULT NULL,
    `message` TEXT DEFAULT NULL,
    `actor_name` VARCHAR(100) DEFAULT 'Ukendt',
    `actor_identifier` VARCHAR(100) DEFAULT NULL,
    `target_name` VARCHAR(100) DEFAULT NULL,
    `target_identifier` VARCHAR(100) DEFAULT NULL,
    `amount` INT(11) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_job_created` (`job_name`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Jobs oprettes kun hvis de ikke allerede findes.
-- Dine eksisterende labels/rangs bliver ikke overskrevet.
INSERT IGNORE INTO `jobs` (`name`, `label`) VALUES
('police', 'Politi'),
('ambulance', 'Ambulance'),
('brand', 'Brandvæsen'),
('viking', 'Viking Autohjælp'),
('autoexotic', 'AutoExotic');

-- Society-konti oprettes kun hvis de ikke allerede findes.
INSERT IGNORE INTO `addon_account` (`name`, `label`, `shared`) VALUES
('society_police', 'Politi', 1),
('society_ambulance', 'Ambulance', 1),
('society_brand', 'Brandvæsen', 1),
('society_viking', 'Viking Autohjælp', 1),
('society_autoexotic', 'AutoExotic', 1);

INSERT IGNORE INTO `addon_account_data` (`account_name`, `money`) VALUES
('society_police', 0),
('society_ambulance', 0),
('society_brand', 0),
('society_viking', 0),
('society_autoexotic', 0);
