select * from products
select * from reorders
select * from shipments
select * from stock_entries
select * from suppliers

--1 total suppliers
select count(*) as total_suppliers from suppliers

--2 total products
select count(*) as total_products from products

--3 total categories dealing 
select count(distinct category)as total_categories from products

--4 total sales value made in last 3 months(quantity*price)
select round(sum(abs(se.change_quantity)*p.price),2) as total_sales_value_in_last_3_months
from stock_entries as se
join products p
on p.product_id=se.product_id
where se.change_type="Sale"
and
se.entry_date>=
(
select date_sub(max(entry_date),interval 3 month) from stock_entries
)

--5 Total restock value made in last 3 month (quantity * price)
select round(sum(abs(se.change_quantity)* p.price),2) as total_restock_value_in_last_3_months
from stock_entries as se
join products p
on p.product_id=se.product_id
where se.change_type="Restock"
and
se.entry_date>=
(
select date_sub(max(entry_date),interval 3 month) from stock_entries
)

--6
select count(*) from products as p where p.stock_quantity<p.reorder_level
and product_id NOT IN
(
select distinct product_id from reorders where status="Pending"
)


--7 suppliers adn their contact details
select supplier_name, contact_name , email , phone from suppliers

--8 Product with their suppliers and current stock
select p.product_name,s.supplier_name,p.stock_quantity,p.reorder_level
from products as p
join suppliers s on
p.supplier_id = s.supplier_id
order by p.product_name ASC

--9 Product needing reorder
select product_id , product_name , stock_quantity , reorder_level from  products where stock_quantity<reorder_level

--10 Add an new product to the database 
DELIMITER $$

DROP PROCEDURE IF EXISTS AddNewProductManualID $$

CREATE PROCEDURE AddNewProductManualID(
    IN p_name VARCHAR(300),
    IN p_category VARCHAR(150),
    IN p_price DECIMAL(10,2),
    IN p_stock INT,
    IN p_reorder INT,
    IN p_supplier INT
)
BEGIN
    DECLARE new_prod_id INT;
    DECLARE new_shipment_id INT;
    DECLARE new_entry_id INT;

    -- Generate Product ID
    SELECT IFNULL(MAX(product_id),0) + 1
    INTO new_prod_id
    FROM products;

    INSERT INTO products
    (
        product_id,
        product_name,
        category,
        price,
        stock_quantity,
        reorder_level,
        supplier_id
    )
    VALUES
    (
        new_prod_id,
        p_name,
        p_category,
        p_price,
        p_stock,
        p_reorder,
        p_supplier
    );

    -- Generate Shipment ID
    SELECT IFNULL(MAX(shipment_id),0) + 1
    INTO new_shipment_id
    FROM shipments;

    INSERT INTO shipments
    (
        shipment_id,
        product_id,
        supplier_id,
        quantity_received,
        shipment_date
    )
    VALUES
    (
        new_shipment_id,
        new_prod_id,
        p_supplier,
        p_stock,
        CURDATE()
    );

    -- Generate Stock Entry ID
    SELECT IFNULL(MAX(entry_id),0) + 1
    INTO new_entry_id
    FROM stock_entries;

    INSERT INTO stock_entries
    (
        entry_id,
        product_id,
        change_quantity,
        change_type,
        entry_date
    )
    VALUES
    (
        new_entry_id,
        new_prod_id,
        p_stock,
        'Restock',
        CURDATE()
    );

END $$

DELIMITER ;

CALL AddNewProductManualID(
    'Smart Watch',
    'Electronics',
    99.99,
    100,
    25,
    5
);

--11 Product History , [ finding shipment,sales,purchase]
create or replace view product_inventory_history as
select
pih.product_id,
pih.record_type,
pih.record_date,
pih.Quantity,
pih.change_type,
pr.supplier_id
from
(
select product_id,
"Shipment" as record_type,
shipment_date as record_date,
quantity_received as Quantity,
null change_type
from shipments

union all

select
product_id,
'Stock Entry' as record_type,
entry_date as record_date,
change_quantity as quantity,
change_type
from stock_entries
)pih
join products pr on pr.product_id= pih.product_id;

select*from
product_inventory_history
where product_id=123
order by record_date desc

--12 Place an reorder
insert into reorders(reorder_id , product_id , reorder_quantity, reorder_date,status)
select max(reorder_id)+1,101,200,curdate(),"ordered" from reorders


select * from stock_entries;
select * from shipments;
select * from reorders;
select * from products;

--13 receive 
DELIMITER $$

DROP PROCEDURE IF EXISTS MarkReorderAsReceived $$

CREATE PROCEDURE MarkReorderAsReceived(IN in_reorder_id INT)
BEGIN
    DECLARE prod_id INT;
    DECLARE qty INT;
    DECLARE sup_id INT;
    DECLARE new_shipment_id INT;
    DECLARE new_entry_id INT;

    START TRANSACTION;

    -- Get product_id and quantity from reorders
    SELECT product_id, reorder_quantity
    INTO prod_id, qty
    FROM reorders
    WHERE reorder_id = in_reorder_id;

    -- Get supplier_id from products
    SELECT supplier_id
    INTO sup_id
    FROM products
    WHERE product_id = prod_id;

    -- Update reorder status
    UPDATE reorders
    SET status = 'Received'
    WHERE reorder_id = in_reorder_id;

    -- Update stock quantity
    UPDATE products
    SET stock_quantity = stock_quantity + qty
    WHERE product_id = prod_id;

    -- Insert shipment record
    SELECT IFNULL(MAX(shipment_id),0) + 1
    INTO new_shipment_id
    FROM shipments;

    INSERT INTO shipments
    (
        shipment_id,
        product_id,
        supplier_id,
        quantity_received,
        shipment_date
    )
    VALUES
    (
        new_shipment_id,
        prod_id,
        sup_id,
        qty,
        CURDATE()
    );

    -- Insert stock entry
    SELECT IFNULL(MAX(entry_id),0) + 1
    INTO new_entry_id
    FROM stock_entries;

    INSERT INTO stock_entries
    (
        entry_id,
        product_id,
        change_quantity,
        change_type,
        entry_date
    )
    VALUES
    (
        new_entry_id,
        prod_id,
        qty,
        'Restock',
        CURDATE()
    );

    COMMIT;
END $$

DELIMITER ;

SET SQL_SAFE_UPDATES = 0;

CALL MarkReorderAsReceived(2);

SELECT * FROM reorders WHERE reorder_id = 2;

SELECT * FROM products WHERE product_name = 'someone shirt';

SELECT * FROM stock_entries
WHERE product_id = 164
ORDER BY entry_date DESC;

SELECT * FROM shipments
ORDER BY shipment_id DESC;