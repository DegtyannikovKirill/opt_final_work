# opt_final_work
Репозиторий по последней работе курса оптимизации


Запрос 1
  SQL ID: bc2gaq30sdxqm Plan Hash: 1113663330

  SELECT /*+ cardinality(pi 1000) leading(p pi)*/ P.PAYMENT_ID ,P.CURRENCY_ID ,
    P.SUMMA ,P.FROM_CLIENT_ID ,P.TO_CLIENT_ID 
  FROM
   TABLE(:B1 ) PI JOIN PAYMENT P ON P.PAYMENT_ID = VALUE(PI)


  call     count       cpu    elapsed       disk      query    current        rows
  ------- ------  -------- ---------- ---------- ---------- ----------  ----------
  Parse        1      0.00       0.00          0          0          0           0
  Execute      1      0.00       0.00          0          3          0           0
  Fetch        1      2.59       7.75      57009      46918          0          10
  ------- ------  -------- ---------- ---------- ---------- ----------  ----------
  total        3      2.59       7.75      57009      46921          0          10

  Misses in library cache during parse: 1
  Misses in library cache during execute: 1
  Optimizer mode: ALL_ROWS
  Parsing user id: 109     (recursive depth: 1)
  Number of plan statistics captured: 1

  Rows (1st) Rows (avg) Rows (max)  Row Source Operation
  ---------- ---------- ----------  ---------------------------------------------------
          10         10         10  HASH JOIN  (cr=46918 pr=57009 pw=22382 time=7750492 us starts=1 cost=26063 size=29670 card=989)
     4685000    4685000    4685000   PARTITION RANGE ALL PARTITION: 1 1048575 (cr=46918 pr=46810 pw=0 time=3195190 us starts=1 cost=17301 size=128811060 card=4600395)
     4685000    4685000    4685000    TABLE ACCESS FULL PAYMENT PARTITION: 1 1048575 (cr=46918 pr=46810 pw=0 time=3181168 us starts=48 cost=17301 size=128811060 card=4600395)
          10         10         10   COLLECTION ITERATOR PICKLER FETCH (cr=0 pr=0 pw=0 time=15 us starts=1 cost=39 size=2000 card=1000)


  Elapsed times include waiting on following events:
    Event waited on                             Times   Max. Wait  Total Waited
    ----------------------------------------   Waited  ----------  ------------
    PGA memory operation                          129        0.00          0.00
    reliable message                                1        0.00          0.00
    enq: KO - fast object checkpoint                1        0.01          0.01
    Disk file operations I/O                        2        0.00          0.00
    direct path read                            11984        0.04          1.99
    asynch descriptor resize                        4        0.00          0.00
    direct path write temp                        722        0.06          1.93
    direct path read temp                         329        0.00          0.43
  ********************************************************************************

  Какие проблемы
    HASH JOIN. Из-за leading(p pi) неверная последовательность соединения. 
  Какие действия были предприняты
    1) Переопределить кардинальность. Это табличная функция, можно определять кардинальность динамический через DYNAMIC_SAMPLING(pi, 2)
    2) Объемы не сильно огромные 300к так что тут будет NL и доступ к payment будет по payment_id ( их мы как раз в массиве ранее получили)
  Итоговая версия запроса ( с реальной статистикой)

  select /*+ DYNAMIC_SAMPLING(pi, 2)*/
         p.payment_id
        ,p.currency_id
        ,p.summa
        ,p.from_client_id
        ,p.to_client_id
    from table(v_payment_ids) pi
    join payment p
      on p.payment_id = value(pi)
   
  ----------------------------------------------------------------------------------------------------------------------------------------------------
  | Id  | Operation                               | Name       | Starts | E-Rows | E-Time   | Pstart| Pstop | A-Rows |   A-Time   | Buffers | Reads  |
  ----------------------------------------------------------------------------------------------------------------------------------------------------
  |   0 | SELECT STATEMENT                        |            |      1 |        |          |       |       |     10 |00:00:00.01 |      26 |      4 |
  |   1 |  NESTED LOOPS                           |            |      1 |     10 | 00:00:01 |       |       |     10 |00:00:00.01 |      26 |      4 |
  |   2 |   NESTED LOOPS                          |            |      1 |     10 | 00:00:01 |       |       |     10 |00:00:00.01 |      16 |      4 |
  |   3 |    COLLECTION ITERATOR CONSTRUCTOR FETCH|            |      1 |     10 | 00:00:01 |       |       |     10 |00:00:00.01 |       0 |      0 |
  |*  4 |    INDEX UNIQUE SCAN                    | PAYMENT_PK |     10 |      1 | 00:00:01 |       |       |     10 |00:00:00.01 |      16 |      4 |
  |   5 |   TABLE ACCESS BY GLOBAL INDEX ROWID    | PAYMENT    |     10 |      1 | 00:00:01 | ROWID | ROWID |     10 |00:00:00.01 |      10 |      0 |
  ----------------------------------------------------------------------------------------------------------------------------------------------------
  

Запрос 2
  SQL ID: cb7ddwf5x8qs9 Plan Hash: 4070027741

  SELECT P.PAYMENT_ID 
  FROM
   PAYMENT P WHERE P.STATUS = :B2 AND ROWNUM <= :B1 FOR UPDATE SKIP LOCKED


  call     count       cpu    elapsed       disk      query    current        rows
  ------- ------  -------- ---------- ---------- ---------- ----------  ----------
  Parse        1      0.00       0.00          0          0          0           0
  Execute      1      0.00       0.00          0          0          0           0
  Fetch        1      0.00       0.00          0          4         12          10
  ------- ------  -------- ---------- ---------- ---------- ----------  ----------
  total        3      0.00       0.00          0          4         12          10

  Misses in library cache during parse: 1
  Misses in library cache during execute: 1
  Optimizer mode: ALL_ROWS
  Parsing user id: 109     (recursive depth: 1)
  Number of plan statistics captured: 1

  Rows (1st) Rows (avg) Rows (max)  Row Source Operation
  ---------- ---------- ----------  ---------------------------------------------------
          10         10         10  FOR UPDATE  (cr=4 pr=0 pw=0 time=312 us starts=1)
          10         10         10   COUNT STOPKEY (cr=4 pr=0 pw=0 time=130 us starts=1)
          10         10         10    PARTITION RANGE ALL PARTITION: 1 1048575 (cr=4 pr=0 pw=0 time=125 us starts=1 cost=2 size=100 card=10)
          10         10         10     TABLE ACCESS FULL PAYMENT PARTITION: 1 1048575 (cr=4 pr=0 pw=0 time=110 us starts=2 cost=2 size=100 card=10)

  ********************************************************************************
  Какие проблемы
    PARTITION RANGE ALL. Таблица секционированная. От бизнеса требование обработать плаатежи за 7 дней. Так что надо добавить предикат по CREATE_DTIME, чтобы потдягивалась нужные партиции, а не вся табилца

  Какие действия были предприняты
    1) Добавить условаие в запрос p.create_dtime >= current_date - c_limit_create_dtime, где c_limit_create_dtime = 7
    2) Нужен локальный индекс внутри партиции по STATUS.
  DDL
    CREATE INDEX PAYMENT_STATUS ON PAYMENT (STATUS) LOCAL ONLINE;
  Итоговая версия запроса ( с реальной статистикой)
  
  select p.payment_id
    bulk collect
    into v_payment_ids
    from payment p
   where p.status = payment_api_pack.c_created
     and p.create_dtime >= current_date - c_limit_create_dtime
     and rownum <= p_bulk_size
     for update skip locked;
  ---------------------------------------------------------------------------------------------------------------------------------------------------
  | Id  | Operation                                   | Name           | Starts | E-Rows | E-Time   | Pstart| Pstop | A-Rows |   A-Time   | Buffers |
  ---------------------------------------------------------------------------------------------------------------------------------------------------
  |   0 | SELECT STATEMENT                            |                |      1 |        |          |       |       |     10 |00:00:00.01 |       4 |
  |*  1 |  COUNT STOPKEY                              |                |      1 |        |          |       |       |     10 |00:00:00.01 |       4 |
  |   2 |   PARTITION RANGE ITERATOR                  |                |      1 |     11 | 00:00:01 |   KEY |1048575|     10 |00:00:00.01 |       4 |
  |*  3 |    TABLE ACCESS BY LOCAL INDEX ROWID BATCHED| PAYMENT        |      1 |     11 | 00:00:01 |   KEY |1048575|     10 |00:00:00.01 |       4 |
  |*  4 |     INDEX RANGE SCAN                        | PAYMENT_STATUS |      1 |        | 00:00:01 |   KEY |1048575|     10 |00:00:00.01 |       2 |
  ---------------------------------------------------------------------------------------------------------------------------------------------------

Запрос 3
SQL ID: ajha9n3da642v Plan Hash: 1994408538

SELECT /*+ index(w1 WALLET_CLIENT_FK) index(w2 WALLET_CLIENT_FK)*/ 
  CL.IS_ACTIVE ,CL.IS_BLOCKED ,W.WALLET_ID ,W.STATUS_ID 
FROM
 CLIENT CL LEFT JOIN WALLET W ON W.CLIENT_ID = CL.CLIENT_ID WHERE 
  CL.CLIENT_ID = :B1 


call     count       cpu    elapsed       disk      query    current        rows
------- ------  -------- ---------- ---------- ---------- ----------  ----------
Parse        1      0.00       0.00          0          0          0           0
Execute     10      0.00       0.00          0          0          0           0
Fetch       10      0.95       1.30        141     239840          0          10
------- ------  -------- ---------- ---------- ---------- ----------  ----------
total       21      0.96       1.30        141     239840          0          10

Misses in library cache during parse: 1
Misses in library cache during execute: 1
Optimizer mode: ALL_ROWS
Parsing user id: 109     (recursive depth: 1)
Number of plan statistics captured: 1

Rows (1st) Rows (avg) Rows (max)  Row Source Operation
---------- ---------- ----------  ---------------------------------------------------
         1          1          1  NESTED LOOPS OUTER (cr=23984 pr=106 pw=0 time=496580 us starts=1 cost=9182 size=25 card=1)
         1          1          1   TABLE ACCESS BY INDEX ROWID CLIENT (cr=4 pr=2 pw=0 time=740 us starts=1 cost=3 size=11 card=1)
         1          1          1    INDEX UNIQUE SCAN CLIENT_PK (cr=3 pr=1 pw=0 time=392 us starts=1 cost=2 size=0 card=1)(object id 72998)
         1          1          1   TABLE ACCESS FULL WALLET (cr=23980 pr=104 pw=0 time=495833 us starts=1 cost=9179 size=14 card=1)


Elapsed times include waiting on following events:
  Event waited on                             Times   Max. Wait  Total Waited
  ----------------------------------------   Waited  ----------  ------------
  db file sequential read                       141        0.05          0.11
********************************************************************************
Какие проблемы
  1) Нет индекса на WALLET по CLIENT_ID
  2) Неверно написаны хинты
Какие действия были предприняты
  1) Убрать хинты, которые "мешают" оптимизатору
  2) Создан индекса на WALLET по CLIENT_ID
  DDL 
    CREATE UNIQUE INDEX WALLET_CLIENT_ID ON WALLET (CLIENT_ID) ONLINE;
  Итоговая версия запроса ( с реальной статистикой)
  select cl.is_active
            ,cl.is_blocked
            ,w.wallet_id
            ,w.status_id
        into v_client_is_active
            ,v_client_blocked
            ,v_wallet_id
            ,v_wallet_status_id
        from client cl
        left join wallet w
          on w.client_id = cl.client_id
       where cl.client_id = p_client_id
  -------------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                    | Name             | Starts | E-Rows | E-Time   | A-Rows |   A-Time   | Buffers | Reads  |
-------------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                  |      1 |        |          |      1 |00:00:00.01 |       8 |      8 |
|   1 |  NESTED LOOPS OUTER          |                  |      1 |      1 | 00:00:01 |      1 |00:00:00.01 |       8 |      8 |
|   2 |   TABLE ACCESS BY INDEX ROWID| CLIENT           |      1 |      1 | 00:00:01 |      1 |00:00:00.01 |       4 |      4 |
|*  3 |    INDEX UNIQUE SCAN         | CLIENT_PK        |      1 |      1 | 00:00:01 |      1 |00:00:00.01 |       3 |      3 |
|   4 |   TABLE ACCESS BY INDEX ROWID| WALLET           |      1 |      1 | 00:00:01 |      1 |00:00:00.01 |       4 |      4 |
|*  5 |    INDEX UNIQUE SCAN         | WALLET_CLIENT_ID |      1 |      1 | 00:00:01 |      1 |00:00:00.01 |       3 |      3 |
-------------------------------------------------------------------------------------------------------------------------------


Время выполнения: 560 ms  - с пустым buffer_cache
Время выполнения: 40 ms   - на "горячей" системе