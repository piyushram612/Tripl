package com.waypointlattice.tripl.utils

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

class TriplDatabaseHelper private constructor(context: Context) :
    SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        const val DATABASE_NAME = "tripl.db"
        const val DATABASE_VERSION = 1
        const val TABLE_TRANSACTIONS = "transactions"

        @Volatile
        private var instance: TriplDatabaseHelper? = null

        fun getInstance(context: Context): TriplDatabaseHelper {
            return instance ?: synchronized(this) {
                instance ?: TriplDatabaseHelper(context.applicationContext).also { instance = it }
            }
        }
    }

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.setForeignKeyConstraintsEnabled(true)
        try {
            db.enableWriteAheadLogging()
        } catch (e: Exception) {
            Log.w("TriplDbHelper", "Could not enable WAL mode: ${e.message}")
        }
    }

    override fun onCreate(db: SQLiteDatabase) {
        Log.d("TriplDbHelper", "Creating SQLite database tables from Android native...")
        db.execSQL("""
            CREATE TABLE IF NOT EXISTS transactions (
                id TEXT PRIMARY KEY NOT NULL,
                amount REAL NOT NULL,
                merchant TEXT NOT NULL,
                date TEXT NOT NULL,
                paymentMethod TEXT NOT NULL,
                category TEXT NOT NULL,
                notes TEXT NOT NULL DEFAULT '',
                paidTo TEXT NOT NULL DEFAULT '',
                needsVerification INTEGER NOT NULL DEFAULT 0,
                reminderDate TEXT,
                wasFinishLater INTEGER NOT NULL DEFAULT 0,
                hideFromLedger INTEGER NOT NULL DEFAULT 0,
                groupId TEXT,
                isIncome INTEGER NOT NULL DEFAULT 0
            );
        """.trimIndent())
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date DESC);")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category);")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_transactions_group_id ON transactions(groupId);")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_transactions_payment_method ON transactions(paymentMethod);")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        Log.d("TriplDbHelper", "Upgrading database from $oldVersion to $newVersion")
    }

    fun insertTransaction(values: ContentValues): Long {
        return writableDatabase.insertWithOnConflict(
            TABLE_TRANSACTIONS,
            null,
            values,
            SQLiteDatabase.CONFLICT_REPLACE
        )
    }
}
