/* Анализ данных для агентства недвижимости
 * 
 * Чтобы спланировать эффективную бизнес-стратегию на рынке недвижимости, заказчику нужно определить 
 * по времени активности объявления — самые привлекательные для работы сегменты недвижимости Санкт-Петербурга и городов Ленинградской области.
 * 
 * Автор: Матвеева Анна
 * Дата: Декабрь 2024
*/
-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT 
	case when (city_id = '6X8I')  -- Равно Санкт-Петербург
            THEN 'Санкт-Петербург' -- Значение в случае, если условие верно
        ELSE 'ЛенОбл' -- Значение в случае, если условие неверно
    end as Region,
    case 
	    when days_exposition is null then '0 В продаже'
	    when days_exposition between 1 and 30 then '1 До месяца'
	    when days_exposition between 31 and 90 then '2 До трех месяцев'
	    when days_exposition between 91 and 180 then '3 До полугода'
    else '4 Более полугода'
    end as Period_day,
    count(id) as count_id, --кол-во объявлений
    COUNT(id) FILTER (WHERE rooms = 0)::REAL as Квариры_студии, --кол-во квартир-студий
	COUNT(id) FILTER (WHERE rooms > 3)::REAL as Большие_квартиры, -- кол-во квартир с 4 и более комнатами
    avg(last_price)::numeric (10,2) as avg_price, -- средняя стоимость 
    avg(total_area)::numeric (10,2) as avg_total_area, -- средняя площадь
    ---ДОБАВЛЕНА строка---
    avg(last_price/total_area )::numeric (10,0) as avg_price_1m2, -- средняя стоимость 1m2
	percentile_cont(0.5) WITHIN GROUP (ORDER BY(rooms))::numeric (10,2) as mediana_rooms, -- медиана кол-ва комнат
	percentile_cont(0.5) WITHIN GROUP (ORDER BY(balcony))::numeric (10,2) as mediana_balcony, -- медиана кол-ва балконов
	percentile_cont(0.5) WITHIN GROUP (ORDER BY(floors_total))::numeric (10,2) as mediana_floors_total -- медиана кол-ва этажей в доме
FROM real_estate.advertisement a
join real_estate.flats f using (id)
join real_estate.city c using (city_id)
join real_estate.type t using (type_id)
WHERE (type_id = 'F8EM') -- тип н.п. ГОРОД 
	and (EXTRACT (year from first_day_exposition) between 2015 and 2018) -- Года не полные исключаем
	and id IN (SELECT * FROM filtered_id)
group by Region, period_day
order by Region desc , period_day;

-- region         |period_day       |count_id|Квариры_студии|Большие_квартиры|avg_price  |avg_total_area|avg_price_1m2|mediana_rooms|mediana_balcony|mediana_floors_total|
-- ---------------+-----------------+--------+--------------+----------------+-----------+--------------+-------------+-------------+---------------+--------------------+
-- Санкт-Петербург|0 В продаже      |     653|           3.0|            89.0|11418045.70|         81.38|       136108|         3.00|           1.00|                9.00|
-- Санкт-Петербург|1 До месяца      |    1794|          28.0|            70.0| 6092949.22|         54.66|       108920|         2.00|           1.00|               10.00|
-- Санкт-Петербург|2 До трех месяцев|    3020|          36.0|           127.0| 6473286.13|         56.58|       110874|         2.00|           1.00|               12.00|
-- Санкт-Петербург|3 До полугода    |    2244|          13.0|           128.0| 6998081.82|         60.55|       111974|         2.00|           1.00|               10.00|
-- Санкт-Петербург|4 Более полугода |    3506|          17.0|           307.0| 7980344.62|         65.76|       114981|         2.00|           1.00|                9.00|
-- ЛенОбл         |0 В продаже      |     198|           2.0|            14.0| 4674793.98|         62.78|        72926|         2.00|           1.00|                5.00|
-- ЛенОбл         |1 До месяца      |     340|           3.0|             7.0| 3500117.40|         48.75|        71908|         2.00|           1.00|                5.00|
-- ЛенОбл         |2 До трех месяцев|     864|           5.0|            22.0| 3417498.14|         50.85|        67424|         2.00|           1.00|                5.00|
-- ЛенОбл         |3 До полугода    |     553|           5.0|            19.0| 3620472.79|         51.83|        69809|         2.00|           1.00|                5.00|
-- ЛенОбл         |4 Более полугода |     873|           1.0|            39.0| 3773134.33|         55.03|        68215|         2.00|           1.00|                5.00|

-- Результат запроса отвечает на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

-- Задача 2: Сезонность объявлений

-- Определим аномальные значения (выбросы) по значению перцентилей:
SET lc_time = 'ru_RU';
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
--Анализ по дате публикации
advertisement_start as (
select
	--EXTRACT (year FROM first_day_exposition::timestamp) as year_start,
	--EXTRACT (MONTH FROM (first_day_exposition+(days_exposition*'1 day'::interval))::timestamp) as Месяц,	
	---ДОБАВЛЕНО---	
	TO_CHAR(first_day_exposition, 'FMMonth') AS month_s,  -- Месяц в виде полного названия 
	count (*) as количество_размещенных,
	DENSE_RANK() OVER(ORDER BY count (*) DESC) as ранг_кол_ва_размещенных,
	ROUND(AVG(last_price/living_area)) AS Ср_цена_жил_1м2_разм_объяв,  -- Средняя цена за ЖИЛОЙ квадратный метр
	ROUND(AVG(last_price/total_area)) AS Ср_цена_1м2_разм_объяв,  -- Средняя цена за квадратный метр
	ROUND(AVG(living_area)) AS Ср_жил_площадь_разм_объяв,  -- Средняя ЖИЛАЯ площадь
	ROUND(AVG(total_area)) AS Ср_площадь_разм_объяв  -- Средняя площадь
FROM real_estate.advertisement a
join real_estate.flats f using (id)
join real_estate.city c using (city_id)
join real_estate.type t using (type_id)
WHERE   (type_id = 'F8EM') --условие из первичной задачи Город
		and (EXTRACT (year from first_day_exposition) between 2015 and 2018) -- Года не полные исключаем
		and (id IN (SELECT * FROM filtered_id)) --выбираем не аномальные объявы
group by month_s
),
--Анализ снятых объявлений
advertisement_remove as (
select
	--EXTRACT (year FROM first_day_exposition::timestamp) as year_start,
	--EXTRACT (MONTH FROM (first_day_exposition+(days_exposition*'1 day'::interval))::timestamp) as Месяц,
	TO_CHAR((first_day_exposition+(days_exposition*'1 day'::interval)), 'FMMonth') AS month_s,  -- Месяц в виде полного названия, например "Январь"
	count (*) as кол_во_завершенных,
	DENSE_RANK() OVER(ORDER BY count (*) DESC) as ранг_завершенных,
	ROUND(AVG(last_price/living_area)) AS Ср_цена_жил_1м2_заверш_объяв,  -- Средняя цена за квадратный метр
	ROUND(AVG(last_price/total_area)) AS Ср_цена_1м2_заверш_объяв,  -- Средняя цена за квадратный метр
	ROUND(AVG(living_area)) AS Ср_жил_площадь_заверш_объяв,  -- Средняя площадь 
	ROUND(AVG(total_area)) AS Ср_площадь_заверш_объяв  -- Средняя площадь 
FROM real_estate.advertisement a
join real_estate.flats f using (id)
join real_estate.type t using (type_id)
WHERE (type_id = 'F8EM') and --условие из первичной задачи Тип = город
	  (EXTRACT (year from first_day_exposition) between 2015 and 2018) and -- Года не полные исключаем
	  (days_exposition is not null) and --не завершенные объявления не анализируем
	  (id IN (SELECT * FROM filtered_id)) --выбираем не аномальные объявы
group by month_s
)
------------ Выведем объявления без выбросов:
SELECT 	month_s, количество_размещенных, ранг_кол_ва_размещенных, кол_во_завершенных, ранг_завершенных, 
	Ср_цена_1м2_разм_объяв, Ср_площадь_разм_объяв, Ср_цена_жил_1м2_разм_объяв, Ср_жил_площадь_разм_объяв,
	Ср_цена_1м2_заверш_объяв, Ср_площадь_заверш_объяв, Ср_цена_жил_1м2_заверш_объяв, Ср_жил_площадь_заверш_объяв,
	CONCAT(((Ср_цена_1м2_заверш_объяв*100/Ср_цена_1м2_разм_объяв)::numeric(5,2))-100,' %') as ожидание_реальность     
FROM advertisement_start a_s
full join advertisement_remove using (month_s)
order by количество_размещенных DESC;

-- month_s  |количество_размещенных|ранг_кол_ва_размещенных|кол_во_завершенных|ранг_завершенных|Ср_цена_1м2_разм_объяв|Ср_площадь_разм_объяв|Ср_цена_жил_1м2_разм_объяв|Ср_жил_площадь_разм_объяв|Ср_цена_1м2_заверш_объяв|Ср_площадь_заверш_объяв|Ср_цена_жил_1м2_заверш_объяв|Ср_жил_площадь_заверш_объяв|ожидание_реальность|
-- ---------+----------------------+-----------------------+------------------+----------------+----------------------+---------------------+--------------------------+-------------------------+------------------------+-----------------------+----------------------------+---------------------------+-------------------+
-- November |                  1569|                      1|              1301|               2|              105049.0|                 60.0|                  210600.0|                     34.0|                103791.0|                   57.0|                    196047.0|                       32.0|-1.20 %            |
-- October  |                  1437|                      2|              1360|               1|              104065.0|                 59.0|                  196970.0|                     33.0|                104317.0|                   59.0|                    199270.0|                       33.0|0.24 %             |
-- February |                  1369|                      3|              1048|               9|              103059.0|                 60.0|                  198300.0|                     34.0|                103884.0|                   61.0|                    200620.0|                       34.0|0.80 %             |
-- September|                  1341|                      4|              1238|               3|              107563.0|                 61.0|                  205403.0|                     34.0|                104070.0|                   57.0|                    197452.0|                       32.0|-3.25 %            |
-- June     |                  1224|                      5|               771|              11|              104802.0|                 58.0|                  198070.0|                     33.0|                101864.0|                   60.0|                    189194.0|                       34.0|-2.80 %            |
-- August   |                  1166|                      6|              1137|               6|              107035.0|                 59.0|                  198324.0|                     33.0|                100037.0|                   57.0|                    209433.0|                       32.0|-6.54 %            |
-- July     |                  1149|                      7|              1108|               7|              104489.0|                 60.0|                  201241.0|                     33.0|                102291.0|                   59.0|                    192147.0|                       33.0|-2.10 %            |
-- March    |                  1119|                      8|              1071|               8|              102430.0|                 60.0|                  191810.0|                     34.0|                106832.0|                   60.0|                    202893.0|                       34.0|4.30 %             |
-- December |                  1024|                      9|              1175|               5|              104775.0|                 59.0|                  198976.0|                     33.0|                105505.0|                   59.0|                    198819.0|                       33.0|0.70 %             |
-- April    |                  1021|                     10|              1031|              10|              102632.0|                 61.0|                  197634.0|                     34.0|                102444.0|                   59.0|                    196805.0|                       34.0|-0.18 %            |
-- May      |                   891|                     11|               729|              12|              102465.0|                 59.0|                  193344.0|                     33.0|                 99724.0|                   58.0|                    194159.0|                       33.0|-2.68 %            |
-- January  |                   735|                     12|              1225|               4|              106106.0|                 59.0|                  205742.0|                     33.0|                104947.0|                   58.0|                    202279.0|                       33.0|-1.09 %            |

-- Результат запроса отвечает на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?


-- Задача 3: Анализ рынка недвижимости Ленобласти

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT 
	city,
	count(id) as всего_объявлений,
    count(id) filter (where days_exposition is not null) as продано_квартир, --кол-во завершенных объявлений
    count(id) filter (where days_exposition is null) as квартиры_в_продаже, --кол-во активныхобъявлений
    CONCAT((count(id) filter (where days_exposition is not null)::numeric*100 /count(id))::numeric(5,2),'%') as доля_продажи,
    (avg (days_exposition) filter (where days_exposition is not null))::numeric(10,2) as дней_на_сайте,
    avg(last_price/total_area)::numeric (10,2) as avg_price_1m2, -- средняя стоимость 1м2
    avg(total_area)::numeric (10,2) as avg_total_area -- средняя площадь
FROM real_estate.advertisement a
join real_estate.flats f using (id)
join real_estate.city c using (city_id)
join real_estate.type t using (type_id)
WHERE (city_id <> '6X8I') and -- Не равно Санкт-Петербург
	  ---ДОБАВЛЕНО---
	  (EXTRACT (year from first_day_exposition) between 2015 and 2018) and -- Года не полные исключаем
 	  id IN (SELECT * FROM filtered_id)
group by city 
HAVING avg (days_exposition) > 0 and count(id)>50 --фильтры для анализа крупных городов (исключение тех, где объявлений не больше пары десятков)
order by count(id) desc
--продано_квартир desc --кол-во завершенных объявлений
--доля_продажи desc --высокая востребованность квартир 
--дней_на_сайте  --самая быстрая продажа
limit 15;

-- city           |всего_объявлений|продано_квартир|квартиры_в_продаже|доля_продажи|дней_на_сайте|avg_price_1m2|avg_total_area|
-- ---------------+----------------+---------------+------------------+------------+-------------+-------------+--------------+
-- Мурино         |             519|            512|                 7|98.65%      |       150.05|     85629.63|         43.79|
-- Кудрово        |             429|            421|                 8|98.14%      |       162.43|     94380.39|         46.18|
-- Шушары         |             375|            364|                11|97.07%      |       155.38|     78015.64|         54.34|
-- Всеволожск     |             324|            295|                29|91.05%      |       189.95|     68838.55|         55.49|
-- Парголово      |             285|            280|                 5|98.25%      |       156.40|     89515.01|         50.89|
-- Пушкин         |             249|            221|                28|88.76%      |       189.24|    103742.24|         59.75|
-- Колпино        |             206|            200|                 6|97.09%      |       140.34|     74803.89|         52.52|
-- Гатчина        |             198|            189|                 9|95.45%      |       199.51|     68328.42|         51.18|
-- Выборг         |             169|            161|                 8|95.27%      |       188.99|     57619.60|         56.05|
-- Петергоф       |             139|            127|                12|91.37%      |       195.25|     85078.13|         49.64|
-- Сестрорецк     |             132|            127|                 5|96.21%      |       207.35|    104338.61|         61.44|
-- Красное Село   |             121|            118|                 3|97.52%      |       211.60|     71580.91|         52.80|
-- Новое Девяткино|             106|            100|                 6|94.34%      |       179.11|     76381.59|         50.27|
-- Сертолово      |             102|             96|                 6|94.12%      |       180.61|     68643.53|         53.03|
-- Бугры          |              88|             87|                 1|98.86%      |       161.34|     80369.16|         46.48|

-- Результат запроса отвечает на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.