import psycopg2
conn = psycopg2.connect("Host=localhost port=5432 dbname=smartagri_db user=postgres password=minsara@2002")
cur = conn.cursor()
cur.execute('SELECT "Id", "Status", "GenerationMode", "CreatedAt" FROM "SmartBasketWorkflows" ORDER BY "CreatedAt" DESC LIMIT 5')
for row in cur.fetchall():
    print(row)
