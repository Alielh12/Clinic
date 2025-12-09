import mysql.connector

def get_connection():
    return mysql.connector.connect(
        host="localhost",
        user="naanani",
        password="OPEN@@2005",   # your MySQL password here
        database="clinic"
    )
