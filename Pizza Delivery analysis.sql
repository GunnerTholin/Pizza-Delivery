-- 1. How many pizzas were ordered?
select 
	count(*) pizza_ordered
from customer_orders;

-- 2. How many unique customer orders were made?
select 
	count(distinct order_id) unique_ordered
from #customer_orders;

-- 3. How many successful orders were delivered by each runner?
select 
	runner_id,
	count(order_id) as orders
from #runner_orders
where distance <> 0
group by runner_id;

-- 4. How many of each type of pizza was delivered?
select 
	n.pizza_name,
	count(c.pizza_id) as delivered
from #pizza_names n
left join customer_orders c on n.pizza_id = c.pizza_id
left join #runner_orders r on c.order_id = r.order_id
where r.distance <> 0
group by n.pizza_name;

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?
select 
	c.customer_id,
	sum(case when c.pizza_id = 1 then 1
		else 0 end) Meatlovers,
	sum(case when c.pizza_id = 2 then 1
		else 0 end) Vegetarian
from #pizza_names n
left join customer_orders c on n.pizza_id = c.pizza_id
group by c.customer_id;

-- 6. What was the maximum number of pizzas delivered in a single order?
select max(pizza) max_pizza
from 
	(
		select 
			c.order_id,
			count(c.order_id) as pizza
		from customer_orders c
		left join #runner_orders r on c.order_id = r.order_id
		where r.distance <> 0
		group by c.order_id
	)a;

-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
select 
	c.customer_id,
	sum(case when c.exclusions <> '' or c.extras <> '' then 1
		else 0 end) at_least_1_change,
	sum(case when c.exclusions = '' and c.extras = '' then 1
		else 0 end) no_change
from #customer_orders c
left join #runner_orders r on c.order_id = r.order_id
where r.distance <> 0
group by c.customer_id;

-- 8. How many pizzas were delivered that had both exclusions and extras?
select 
	sum(case when c.exclusions <> '' and c.extras <> '' then 1
		else 0 end) delivered
from #customer_orders c
left join #runner_orders r on c.order_id = r.order_id
where r.distance <> 0;

-- 9. What was the total volume of pizzas ordered for each hour of the day?
select 
	datepart(HOUR, order_time) hour_of_day,
	count(order_id) total
from #customer_orders
group by datepart(HOUR, order_time);

-- 10. What was the volume of orders for each day of the week?
select 
	datename(DW, DATEADD(day, 2, order_time)) day_of_week, --adjust first day of week as Monday by adding 2
	count(order_id) total
from #customer_orders
group by datename(DW, DATEADD(day, 2, order_time)), datepart(DW, DATEADD(day, 2, order_time))
order by datepart(DW, DATEADD(day, 2, order_time));

-- 11. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SET DATEFIRST 5; --because January 1, 2021 is a Friday, specifies Friday as the first day of the week
select 
	datepart(WK, registration_date) weeks,
	count(runner_id) total
from runners
group by datepart(WK, registration_date);

-- 12. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
select 
	runner_id,
	AVG(times) times
from 
	(
		select distinct 
			c.order_id, r.runner_id, 
			datediff(MINUTE, c.order_time, r.pickup_time) times
		from #customer_orders c
		left join #runner_orders r on c.order_id = r.order_id
		where r.distance <> 0
	)a
group by runner_id;

-- 13. Is there any relationship between the number of pizzas and how long the order takes to prepare?
select 
	number_of_pizzas,
	avg(times) order_prepare
from 
	(
		select distinct 
			c.order_id, COUNT(c.pizza_id) number_of_pizzas, c.order_time, r.pickup_time, 
			datediff(MINUTE, c.order_time, r.pickup_time) times
		from #customer_orders c
		left join #runner_orders r on c.order_id = r.order_id
		where r.distance <> 0
		group by c.order_id, c.order_time, r.pickup_time
	)a
group by number_of_pizzas;

-- 14. What was the average distance travelled for each customer?
select 
	c.customer_id,
	AVG(distinct r.distance) distance
from #customer_orders c
left join #runner_orders r on c.order_id = r.order_id
where r.distance <> 0
group by c.customer_id;

-- 15. What was the difference between the longest and shortest delivery times for all orders?
select 
	MAX(duration) - min(duration) diff_delivery_time
from #runner_orders
where duration <> 0;

-- 16. What was the average speed for each runner for each delivery and do you notice any trend for these values?
select distinct 
	c.order_id, r.runner_id, COUNT(c.pizza_id) number_of_pizzas, 
	r.distance, r.duration, round((r.distance/r.duration*60),2) speed
from #customer_orders c
left join #runner_orders r on c.order_id = r.order_id
where r.distance <> 0
group by c.order_id, r.runner_id, r.distance, r.duration;

-- 17. What is the successful delivery percentage for each runner?
select 
	runner_id, 
	ROUND(100 * SUM(case when distance <> 0 then 1 
						else 0 end)/COUNT(*),0) percentage
from #runner_orders
group by runner_id;

--18. What are the standard ingredients for each pizza? */
select 
	n.pizza_name,
	STRING_AGG(t.topping_name,', ') ingredients
from #pizza_names n
left join #pizza_recipes r on n.pizza_id = r.pizza_id
left join #pizza_toppings t on r.toppings = t.topping_id
group by n.pizza_name;

--19. What was the most commonly added extra? */
SELECT 
	t.topping_id, 
	t.topping_name, 
	COUNT(c.extras) added
FROM #pizza_toppings t 
left join 
	(
		select distinct 
			order_id, 
			extras 
		from #customer_orders_split
	)c on t.topping_id = c.extras
group by t.topping_id, t.topping_name
having COUNT(c.extras) <> 0;

-- 20. What was the most common exclusion? */
SELECT 
	t.topping_id, 
	t.topping_name, 
	COUNT(c.exclusions) removed
FROM #pizza_toppings t 
left join 
	(
		select distinct 
			order_id, 
			exclusions 
		from #customer_orders_split
	)c on t.topping_id = c.exclusions
group by t.topping_id, t.topping_name
having COUNT(c.exclusions) <> 0
order by t.topping_id;

--21. Generate an order item for each record in the customers_orders table in the format of one of the following: 
	--* Meat Lovers. 
	--* Meat Lovers - Exclude Beef. 
	--* Meat Lovers - Extra Bacon. 
	--* Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers*/
select 
	order_id, customer_id, pizza_id, exclusions, extras, order_time,
	CONCAT(pizza_name, ' ', exc, ' ', ext) order_item
from
	(
		select 
			order_id, customer_id, pizza_id, exclusions, 
			extras, order_time, pizza_name,
			case when tc1 is null then ''
				when tc2 is null then CONCAT('- Exclude', ' ', tc1)
				else CONCAT('- Exclude', ' ', tc1, ', ', tc2)
				end exc,
			case when tx1 is null then ''
				when tx2 is null then CONCAT('- Extra', ' ', tx1)
				else CONCAT('- Extra', ' ', tx1, ', ', tx2)
				end ext
		from
			(
				select 
					order_id, customer_id, 
					a.pizza_id, exclusions, 
					extras, order_time,
					case when exc1 is null then '' else exc1 end exc1,
					case when exc2 is null then '' else exc2 end exc2,
					case when ext1 is null then '' else ext1 end ext1,
					case when ext2 is null then '' else ext2 end ext2
					, n.pizza_name
					, tc1.topping_name tc1, tc2.topping_name tc2
					, tx1.topping_name tx1, tx2.topping_name tx2
				from
					(
						select *,
							CAST(LEFT(exclusions, CHARINDEX(',', exclusions + ',') -1) as int) exc1,
							CAST(STUFF(exclusions, 1, Len(exclusions) +1- CHARINDEX(',',Reverse(exclusions)), '') as int) exc2,
							CAST(LEFT(extras, CHARINDEX(',', extras + ',') -1) as int) ext1,
							CAST(STUFF(extras, 1, Len(extras) +1- CHARINDEX(',',Reverse(extras)), '') as int) ext2
						from #customer_orders
					)a
				left join #pizza_names n on a.pizza_id = n.pizza_id
				left join #pizza_toppings tc1 on a.exc1 = tc1.topping_id
				left join #pizza_toppings tc2 on a.exc2 = tc2.topping_id
				left join #pizza_toppings tx1 on a.ext1 = tx1.topping_id
				left join #pizza_toppings tx2 on a.ext2 = tx2.topping_id
			)b
	)c;

--22.. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients.
	--For example: "Meat Lovers: 2xBacon, Beef, ... , Salami" */
SELECT
	f.order_id, cn.customer_id, cn.pizza_id, cn.exclusions, cn.extras, cn.order_time,
	CONCAT(f.pizza_name, ': ', f.list) ingredient_list
FROM 
	(
		SELECT
			no, order_id, pizza_id, pizza_name,
			STRING_AGG(counts, ', ') list
		FROM
			(
				SELECT
					no, order_id, pizza_id, pizza_name, topping_id,
					CASE WHEN counts = 1 THEN topping_name 
						ELSE CONCAT(counts, 'x ',topping_name) END counts
				FROM
					(
						SELECT
							no, order_id, customer_id, pizza_id,
							pizza_name, topping_id, topping_name,
							COUNT(topping_id) counts
						FROM 
						(
SELECT 
	b.*, t.topping_name
FROM
(
	SELECT 
		no, order_id, customer_id, 
		pizza_id, pizza_name, topping_id
	FROM
	(	-- orders ingredient recipes
		select c.no, c.order_id, c.customer_id, n.*, t.*
		from #customer_orders c
		left join #pizza_names n on c.pizza_id = n.pizza_id
		left join #pizza_recipes r on c.pizza_id = r.pizza_id
		left join #pizza_toppings t on r.toppings = t.topping_id
	)a
		EXCEPT
SELECT
	*
	FROM
	(	-- split row in exclusions column
		SELECT 
			c.no, c.order_id, c.customer_id, c.pizza_id, 
			n.pizza_name, cast(trim(value) as int) exclusions
		FROM #customer_orders c
		left join #pizza_names n on c.pizza_id = n.pizza_id
		CROSS APPLY STRING_SPLIT(c.exclusions, ',')
	)exclusions_orders
		UNION ALL
SELECT
	*
FROM
	(	-- split row in extras column
		SELECT 
			c.no, c.order_id, c.customer_id, c.pizza_id, 
			n.pizza_name, cast(trim(value) as int) extras
		FROM #customer_orders c
		left join #pizza_names n on c.pizza_id = n.pizza_id
		CROSS APPLY STRING_SPLIT(c.extras, ',')
		where cast(trim(value) as int) != 0
	)extras_orders
)b
left join #pizza_toppings t on b.topping_id = t.topping_id
						)c
						GROUP BY
							no, order_id, customer_id, pizza_id,
							pizza_name, topping_id, topping_name
					)d
			)e
		GROUP BY
			no, order_id, pizza_id, pizza_name
	)f
left join #customer_orders cn on cn.no = f.no
ORDER BY f.no, f.order_id, f.pizza_id;

--23. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first? */
SELECT
	topping_id, topping_name,
	COUNT(topping_id) counts
						FROM 
						(
SELECT 
	b.*, t.topping_name
FROM
(
	SELECT 
		no, order_id, customer_id, pizza_id, 
		pizza_name, topping_id
	FROM
	(	-- orders ingredient recipes
		select 
			c.no, c.order_id, 
			c.customer_id, n.*, t.*
		from #customer_orders c
		left join #pizza_names n on c.pizza_id = n.pizza_id
		left join #pizza_recipes r on c.pizza_id = r.pizza_id
		left join #pizza_toppings t on r.toppings = t.topping_id
	)a
		EXCEPT
SELECT
	*
	FROM
	(	-- split row in exclusions column
		SELECT 
			c.no, c.order_id, c.customer_id, c.pizza_id, 
			n.pizza_name, cast(trim(value) as int) exclusions
		FROM #customer_orders c
		left join #pizza_names n on c.pizza_id = n.pizza_id
		CROSS APPLY STRING_SPLIT(c.exclusions, ',')
	)exclusions_orders
		UNION ALL
SELECT
	*
FROM
	(	-- split row in extras column
		SELECT 
			c.no, c.order_id, c.customer_id, c.pizza_id, 
			n.pizza_name, cast(trim(value) as int) extras
		FROM #customer_orders c
		left join #pizza_names n on c.pizza_id = n.pizza_id
		CROSS APPLY STRING_SPLIT(c.extras, ',')
		where cast(trim(value) as int) != 0
	)extras_orders
)b
left join #pizza_toppings t on b.topping_id = t.topping_id
left join #runner_orders r on b.order_id = r.order_id
where r.distance != 0
						)c
GROUP BY topping_id, topping_name
Order by counts desc, topping_id;