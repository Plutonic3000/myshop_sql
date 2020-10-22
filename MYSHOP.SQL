-- MySQL dump 10.13  Distrib 5.1.73, for redhat-linux-gnu (x86_64)
--
-- Host: localhost    Database: emtea
-- ------------------------------------------------------
-- Server version	5.1.73

--
-- Table structure for table `_svc_alert`
--

DROP TABLE IF EXISTS `_svc_alert`;
CREATE TABLE `_svc_alert` (
  `alertid` int(10) NOT NULL AUTO_INCREMENT,
  `name` varchar(20) NOT NULL,
  `value` int(10) unsigned NOT NULL,
  PRIMARY KEY (`alertid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `_svc_product`
--

DROP TABLE IF EXISTS `_svc_product`;
CREATE TABLE `_svc_product` (
  `productid` int(10) NOT NULL AUTO_INCREMENT,
  `flag` varchar(4) DEFAULT NULL,
  PRIMARY KEY (`productid`)
) ENGINE=InnoDB AUTO_INCREMENT=131 DEFAULT CHARSET=utf8;

--
-- Table structure for table `_svc_stat`
--

DROP TABLE IF EXISTS `_svc_stat`;
CREATE TABLE `_svc_stat` (
  `statid` int(10) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `value` varchar(50) NOT NULL,
  PRIMARY KEY (`statid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `_svc_vars`
--

DROP TABLE IF EXISTS `_svc_vars`;
CREATE TABLE `_svc_vars` (
  `name` varchar(20) NOT NULL,
  `value` varchar(255) DEFAULT '',
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `admin`
--

DROP TABLE IF EXISTS `admin`;
CREATE TABLE `admin` (
  `adminid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` char(255) DEFAULT NULL,
  `email` char(255) NOT NULL,
  `passwd` char(32) NOT NULL,
  `type` enum('emp','adm','usr') DEFAULT NULL,
  PRIMARY KEY (`adminid`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8;

--
-- Table structure for table `category`
--

DROP TABLE IF EXISTS `category`;
CREATE TABLE `category` (
  `categoryid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `title` char(60) NOT NULL,
  `description` char(255) DEFAULT NULL,
  `parent` int(10) unsigned DEFAULT NULL,
  `showflag` int(1) unsigned DEFAULT NULL,
  PRIMARY KEY (`categoryid`),
  UNIQUE KEY `title` (`title`)
) ENGINE=InnoDB AUTO_INCREMENT=40 DEFAULT CHARSET=utf8;

DELIMITER ;;

CREATE DEFINER=`root`@`localhost` TRIGGER `b_upd_category_flag` BEFORE UPDATE ON `category`
 FOR EACH ROW BEGIN
  IF NEW.showflag=1 THEN
    UPDATE product SET showflag=1 WHERE categoryid=OLD.categoryid;
  ELSE 
    UPDATE product SET showflag=0 WHERE categoryid=OLD.categoryid;
  END IF;
END ;;

DELIMITER ;

--
-- Table structure for table `customer`
--

DROP TABLE IF EXISTS `customer`;
CREATE TABLE `customer` (
  `customerid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` char(255) DEFAULT NULL,
  `address` char(255) DEFAULT NULL,
  `phone` char(100) DEFAULT NULL,
  `email` char(255) DEFAULT NULL,
  PRIMARY KEY (`customerid`),
  UNIQUE KEY `phone` (`phone`)
) ENGINE=InnoDB AUTO_INCREMENT=144 DEFAULT CHARSET=utf8;

DELIMITER ;;

CREATE DEFINER=`root`@`localhost` TRIGGER `b_del_customer` BEFORE DELETE ON `customer`
 FOR EACH ROW BEGIN
  DECLARE endf,orid INT;
  DECLARE cur CURSOR FOR SELECT orderid FROM `order` WHERE customerid = OLD.customerid;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET endf = 1;
  OPEN cur;
    SET endf = 0;
    WHILE endf=0 DO
      FETCH cur INTO orid;
      IF endf = 0 THEN
        CALL delete_order(orid);
      END IF;
    END WHILE;
  CLOSE cur;
END ;;

DELIMITER ;

--
-- Table structure for table `order`
--

DROP TABLE IF EXISTS `order`;
CREATE TABLE `order` (
  `orderid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `customerid` int(10) unsigned NOT NULL,
  `amount` float(12,2) DEFAULT NULL,
  `date` date NOT NULL,
  `microdate` varchar(50) NOT NULL,
  `status` char(60) DEFAULT NULL,
  `ship_pay_id` int(10) unsigned DEFAULT NULL,
  `name` char(255) DEFAULT NULL,
  `address` char(255) DEFAULT NULL,
  `phone` char(100) DEFAULT NULL,
  `email` char(255) DEFAULT NULL,
  PRIMARY KEY (`orderid`),
  KEY `paymentid` (`ship_pay_id`),
  KEY `customerid` (`customerid`),
  FOREIGN KEY (`ship_pay_id`) REFERENCES `ship_pay` (`ship_pay_id`),
  FOREIGN KEY (`customerid`) REFERENCES `customer` (`customerid`)
) ENGINE=InnoDB AUTO_INCREMENT=181 DEFAULT CHARSET=utf8;

--
-- Table structure for table `order_items`
--

DROP TABLE IF EXISTS `order_items`;
CREATE TABLE `order_items` (
  `orderid` int(10) unsigned NOT NULL,
  `productid` int(10) unsigned NOT NULL,
  `itemprice` float(12,2) NOT NULL DEFAULT '0.00',
  `quantity` int(10) unsigned NOT NULL,
  `flag` int(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`orderid`,`productid`),
  KEY `productid` (`productid`),
  FOREIGN KEY (`productid`) REFERENCES `product` (`productid`),
  FOREIGN KEY (`orderid`) REFERENCES `order` (`orderid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DELIMITER ;;

CREATE DEFINER=`root`@`localhost` TRIGGER `b_ins_order_items` BEFORE INSERT ON `order_items`
FOR EACH ROW BEGIN
 SET @pqty = (SELECT quantity FROM product WHERE productid=NEW.productid);
 SET @pprice = (SELECT get_price(NEW.productid));
 IF NEW.quantity < @pqty THEN
  UPDATE product SET quantity=@pqty-NEW.quantity WHERE productid=NEW.productid;
 ELSE
  SET NEW.flag=1;
 END IF;
 SET NEW.itemprice = @pprice;
END ;;

CREATE DEFINER=`root`@`localhost` TRIGGER `a_ins_order_items` AFTER INSERT ON `order_items`
 FOR EACH ROW BEGIN
 CALL recalc_order_total(NEW.orderid);
 CALL check_order_status(NEW.orderid);
END ;;

CREATE DEFINER=`root`@`localhost` TRIGGER `b_upd_order_items` BEFORE UPDATE ON `order_items`
FOR EACH ROW BEGIN
 SET @pqty := (SELECT quantity FROM product WHERE productid=NEW.productid);
 SET @pprice = (SELECT get_price(NEW.productid));
 IF NEW.quantity <> OLD.quantity THEN
  IF OLD.flag < 1 THEN
   IF NEW.quantity > OLD.quantity THEN
    IF (@pqty+OLD.quantity) >= NEW.quantity THEN
     UPDATE product SET quantity = @pqty-(NEW.quantity-OLD.quantity) WHERE productid=NEW.productid;
    ELSE
     UPDATE product SET quantity = @pqty+(OLD.quantity) WHERE productid=NEW.productid;
     SET NEW.flag = 1;
    END IF;
   ELSE
    UPDATE product SET quantity = @pqty+(OLD.quantity-NEW.quantity) WHERE productid=NEW.productid;
   END IF;
  ELSE
   IF @pqty >= NEW.quantity THEN
    UPDATE product SET quantity = @pqty-NEW.quantity WHERE productid=NEW.productid;
    SET NEW.flag=0;
   END IF;
  END IF;
  SET NEW.itemprice = @pprice;
 END IF;
END ;;

CREATE DEFINER=`root`@`localhost` TRIGGER `a_upd_order_items` AFTER UPDATE ON `order_items`
 FOR EACH ROW BEGIN
 CALL recalc_order_total(NEW.orderid);
 CALL check_order_status(NEW.orderid);
END ;;

CREATE DEFINER=`root`@`localhost` TRIGGER `b_del_order_items` BEFORE DELETE ON `order_items`
 FOR EACH ROW BEGIN
IF OLD.flag < 1 THEN
 IF (SELECT status FROM `order` WHERE orderid=OLD.orderid)<>'archive' THEN
  SET @pqty = (SELECT quantity FROM product WHERE productid=OLD.productid);
  UPDATE product SET quantity=@pqty+OLD.quantity WHERE productid=OLD.productid;
 END IF;
END IF;
END ;;

CREATE DEFINER=`root`@`localhost` TRIGGER `a_del_order_items` AFTER DELETE ON `order_items`
 FOR EACH ROW BEGIN
 IF (SELECT status FROM `order` WHERE orderid=OLD.orderid)<>'archive' THEN
  CALL recalc_order_total(OLD.orderid);
  CALL check_order_status(OLD.orderid);
 END IF;
END ;;

DELIMITER ;

--
-- Table structure for table `payment`
--

DROP TABLE IF EXISTS `payment`;
CREATE TABLE `payment` (
  `paymentid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `title` char(50) NOT NULL,
  `description` char(255) DEFAULT NULL,
  PRIMARY KEY (`paymentid`),
  UNIQUE KEY `title` (`title`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8;

DELIMITER ;;

CREATE DEFINER=`root`@`localhost` TRIGGER `b_del_payment` BEFORE DELETE ON `payment`
 FOR EACH ROW BEGIN
  DELETE FROM ship_pay WHERE payid=OLD.paymentid;
END ;;

DELIMITER ;

--
-- Table structure for table `product`
--

DROP TABLE IF EXISTS `product`;
CREATE TABLE `product` (
  `productid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `title` char(60) NOT NULL,
  `description` text,
  `categoryid` int(10) unsigned DEFAULT NULL,
  `price` float(8,2) NOT NULL,
  `quantity` int(10) unsigned DEFAULT NULL,
  `quantitytype` char(10) NOT NULL,
  `showflag` int(1) NOT NULL DEFAULT '0',
  `bestflag` int(1) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`productid`),
  UNIQUE KEY `title` (`title`),
  KEY `categoryid` (`categoryid`),
  FOREIGN KEY (`categoryid`) REFERENCES `category` (`categoryid`)
) ENGINE=InnoDB AUTO_INCREMENT=141 DEFAULT CHARSET=utf8;

DELIMITER ;;

CREATE DEFINER=`root`@`localhost` TRIGGER `a_upd_product` AFTER UPDATE ON `product`
 FOR EACH ROW BEGIN
IF NEW.quantity > OLD.quantity THEN
IF (SELECT COUNT(*) FROM _svc_product WHERE productid = OLD.productid) < 1 THEN
  INSERT INTO _svc_product VALUES(OLD.productid,'up');
END IF;
END IF;
END ;;

DELIMITER ;

--
-- Table structure for table `productdiscount`
--

DROP TABLE IF EXISTS `productdiscount`;
CREATE TABLE `productdiscount` (
  `productid` int(10) unsigned NOT NULL,
  `percent` int(2) unsigned NOT NULL,
  PRIMARY KEY (`productid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `productimg`
--

DROP TABLE IF EXISTS `productimg`;
CREATE TABLE `productimg` (
  `imgid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `productid` int(10) unsigned NOT NULL,
  `title` char(60) NOT NULL,
  `path` char(255) NOT NULL,
  PRIMARY KEY (`imgid`),
  KEY `productid` (`productid`),
  FOREIGN KEY (`productid`) REFERENCES `product` (`productid`)
) ENGINE=InnoDB AUTO_INCREMENT=298 DEFAULT CHARSET=utf8;

--
-- Table structure for table `productreview`
--

DROP TABLE IF EXISTS `productreview`;
CREATE TABLE `productreview` (
  `reviewid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `productid` int(10) unsigned NOT NULL,
  `date` date NOT NULL,
  `name` char(60) NOT NULL,
  `text` char(255) NOT NULL,
  PRIMARY KEY (`reviewid`),
  KEY `productid` (`productid`),
  FOREIGN KEY (`productid`) REFERENCES `product` (`productid`)
) ENGINE=InnoDB AUTO_INCREMENT=105 DEFAULT CHARSET=utf8;

--
-- Table structure for table `ship`
--

DROP TABLE IF EXISTS `ship`;
CREATE TABLE `ship` (
  `shipid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `title` char(60) NOT NULL,
  `description` char(255) DEFAULT NULL,
  `price` float(8,2) NOT NULL,
  PRIMARY KEY (`shipid`),
  UNIQUE KEY `title` (`title`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;

DELIMITER ;;

CREATE DEFINER=`root`@`localhost` TRIGGER `b_del_ship` BEFORE DELETE ON `ship`
FOR EACH ROW BEGIN
DELETE FROM `ship_pay` WHERE shipid=OLD.shipid;
END ;;

DELIMITER ;

--
-- Table structure for table `ship_pay`
--

DROP TABLE IF EXISTS `ship_pay`;
CREATE TABLE `ship_pay` (
  `ship_pay_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `shipid` int(10) unsigned NOT NULL,
  `payid` int(10) unsigned NOT NULL,
  PRIMARY KEY (`ship_pay_id`),
  UNIQUE KEY `shipid_2` (`shipid`,`payid`),
  KEY `shipid` (`shipid`),
  KEY `payid` (`payid`),
  FOREIGN KEY (`shipid`) REFERENCES `ship` (`shipid`),
  FOREIGN KEY (`payid`) REFERENCES `payment` (`paymentid`),
  FOREIGN KEY (`payid`) REFERENCES `payment` (`paymentid`)
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8;

DELIMITER ;;

CREATE DEFINER=`root`@`localhost` TRIGGER `b_del_ship_pay` BEFORE DELETE ON `ship_pay`
 FOR EACH ROW BEGIN
  UPDATE `order` SET ship_pay_id=NULL WHERE ship_pay_id=OLD.ship_pay_id; 
END ;;

DELIMITER ;

--
-- Dumping events for database 'emtea'
--

DROP EVENT IF EXISTS `check_n_replace`;
DELIMITER ;;

CREATE EVENT `check_n_replace` 
ON SCHEDULE EVERY 1 HOUR STARTS '2014-07-22 20:27:56' 
ON COMPLETION NOT PRESERVE ENABLE 
COMMENT 'Replace products from store to orders whitch quantities was turn' 
DO CALL get_replace() ;;

DELIMITER ;

--
-- Dumping routines for database 'emtea'
--

DROP FUNCTION IF EXISTS `get_price`;

DELIMITER ;;

CREATE DEFINER=`root`@`localhost` FUNCTION `get_price`(pid int(10) unsigned) RETURNS float(8,2)
begin
set @discount = (select percent from productdiscount where productid=pid);
set @price = (select price from product where productid=pid);
set @result = @price-(@price/100*@discount);
return ifnull(@result,@price);
end ;;

DROP PROCEDURE IF EXISTS `add_ship_price_to_order`;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `add_ship_price_to_order`(IN orid INT (10) unsigned)
BEGIN
 DECLARE shid INT;
 SET shid = (SELECT shipid FROM ship_pay WHERE ship_pay_id=(SELECT ship_pay_id from `order` WHERE orderid=orid));
 UPDATE `order` SET amount=amount+(SELECT price FROM ship WHERE shipid=shid) WHERE orderid=orid;
END ;;

DROP PROCEDURE IF EXISTS `check_order_status`;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `check_order_status`(IN orid INT (10) unsigned)
BEGIN
 DECLARE endf,f INT(1);
 DECLARE stat,orst CHAR(60);
 DECLARE cur CURSOR FOR SELECT flag FROM order_items WHERE orderid=orid;
 DECLARE CONTINUE HANDLER FOR NOT FOUND SET endf = 1;
 SET orst = (SELECT status FROM `order` WHERE orderid=orid);
 IF orst <> 'archive' THEN
   OPEN cur;
     SET endf = 0;
     SET f = 0;
     SET stat = 'complete';
     cycle : WHILE endf=0 DO
       FETCH cur INTO f;
         IF f = 1 THEN
           SET stat = 'incomplete';
           LEAVE cycle;
         END IF;
     END WHILE;
   CLOSE cur;
   UPDATE `order` SET status=stat WHERE orderid=orid;
 END IF;
END ;;

DROP PROCEDURE IF EXISTS `delete_order`;;

CREATE DEFINER=`root`@`localhost` PROCEDURE `delete_order`(IN orid INT (10) unsigned)
BEGIN
 DELETE FROM order_items WHERE orderid=orid;
 DELETE FROM `order` WHERE orderid=orid;
END ;;

DROP PROCEDURE IF EXISTS `get_replace`;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_replace`()
BEGIN
DECLARE endf,prid INT(10);
DECLARE cur CURSOR FOR SELECT productid FROM _svc_product;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET endf = 1;
OPEN cur;
SET endf=0;
WHILE endf=0 DO
 FETCH cur INTO prid;
 IF endf=0 THEN
   CALL replace_product(prid);
   DELETE FROM _svc_product WHERE productid = prid;
 END IF;
END WHILE;
CLOSE cur;
END ;;

DROP PROCEDURE IF EXISTS `recalc_order_total`;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `recalc_order_total`(IN orid INT (10) unsigned)
BEGIN
 DECLARE endf,qty,COU INT;
 DECLARE total,price FLOAT(12,2);
 DECLARE cur CURSOR FOR SELECT itemprice, quantity FROM order_items WHERE orderid=orid;
 DECLARE CONTINUE HANDLER FOR NOT FOUND SET endf = 1;
 OPEN cur;
  SET endf = 0;
  SET qty = 0;
  SET total = 0.00;
  SET price = 0.00;
  SET COU = 1;
  WHILE endf=0 DO
   FETCH cur INTO price,qty;
   IF endf = 0 THEN
    SET total = total+(price*qty);
   END IF;
  END WHILE;
 CLOSE cur;
 UPDATE `order` SET amount=total WHERE orderid=orid;
 CALL add_ship_price_to_order(orid);
END ;;

DROP PROCEDURE IF EXISTS `replace_product`;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `replace_product`(IN p_id INT (10) unsigned)
BEGIN
DECLARE endf,orid,prid,qty,pqty INT(10);
DECLARE cur CURSOR 
FOR SELECT order_items.orderid,order_items.productid,order_items.quantity 
        FROM `order_items`,`order` WHERE order_items.productid = p_id 
        AND order_items.flag = 1 AND `order`.orderid = order_items.orderid AND `order`.status <> 'archive' 
        ORDER BY orderid;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET endf = 1;
OPEN cur;
SET endf=0;
WHILE endf=0 DO
  FETCH cur INTO orid, prid, qty;
  SET pqty = (SELECT quantity FROM product WHERE productid=p_id);
  IF endf=0 THEN
    IF pqty >= qty THEN
      UPDATE product SET quantity = pqty-qty WHERE productid = prid;
      UPDATE order_items SET flag = 0 WHERE orderid = orid AND productid = prid;
    END IF;
  END IF;
END WHILE;
CLOSE cur;
END ;;

DROP PROCEDURE IF EXISTS `set_discount`;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `set_discount`(IN pid INT(10) unsigned, IN per INT(2) unsigned)
BEGIN
     IF (SELECT COUNT(productid) FROM productdiscount WHERE productid=pid) > 0 THEN
      IF per > 0 THEN
       UPDATE productdiscount SET percent=per WHERE productid=pid;
      ELSE
       DELETE FROM productdiscount WHERE productid=pid;
      END IF;
     ELSE
      INSERT INTO productdiscount VALUES(pid,per);
     END IF;
    END ;;

DELIMITER ;

-- Dump completed on 2017-12-21 15:04:31
