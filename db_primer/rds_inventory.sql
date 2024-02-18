CREATE TABLE IF NOT EXISTS order_history (
   product_id varchar(255) PRIMARY KEY,
   order_reference varchar(255) NOT NULL,
   order_picked boolean NOT NULL,
   order_shipped boolean NOT NULL,
   return_requested boolean NOT NULL,
   return_received boolean NOT NULL,
   product_name varchar(255) NOT NULL
);


INSERT INTO order_history (product_id, order_reference, order_picked, order_shipped, return_requested, return_received, product_name) VALUES('def4', 'abc123', TRUE, FALSE, FALSE, FALSE, 'Coffee Beans');
INSERT INTO order_history (product_id, order_reference, order_picked, order_shipped, return_requested, return_received, product_name) VALUES('ghi5', 'abc123', TRUE, FALSE, FALSE, FALSE, 'Cofee Grinder');
INSERT INTO order_history (product_id, order_reference, order_picked, order_shipped, return_requested, return_received, product_name) VALUES('klm6', 'abc123', TRUE, FALSE, FALSE, FALSE, 'French Press');
