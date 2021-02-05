CREATE TABLE IF NOT EXISTS `player_logs` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `name` varchar(50) DEFAULT NULL,
    `steam` varchar(30) DEFAULT NULL,
    `license` varchar(75) DEFAULT NULL,
    `xbl` varchar(25) DEFAULT NULL,
    `live` varchar(25) DEFAULT NULL,
    `discord` varchar(35) DEFAULT NULL,
    `fivem` varchar(25) DEFAULT NULL,
    `tokens` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
    `ban_time` datetime DEFAULT NULL,
    `ban_reason` varchar(350) DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
