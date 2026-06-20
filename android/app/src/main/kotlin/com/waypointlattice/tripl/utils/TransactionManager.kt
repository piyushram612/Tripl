package com.waypointlattice.tripl.utils

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

object TransactionManager {

    fun saveTransactionToPrefs(
        context: Context,
        titleText: String,
        amountText: String,
        category: String,
        source: String,
        paidTo: String = "",
        needsVerification: Boolean = false,
        reminderDate: String? = null
    ) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val transactionsJson = prefs.getString("flutter.transactions_json", "[]") ?: "[]"
            val jsonArray = JSONArray(transactionsJson)

            val newTx = JSONObject().apply {
                put("id", UUID.randomUUID().toString())
                put("amount", amountText.toDoubleOrNull() ?: 0.0)
                put("merchant", titleText)
                put("paidTo", paidTo)
                put("needsVerification", needsVerification)
                if (reminderDate != null) {
                    put("reminderDate", reminderDate)
                }

                val df = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }
                put("date", df.format(Date()))
                put("paymentMethod", source)
                put("category", category)
            }

            jsonArray.put(newTx)
            prefs.edit().putString("flutter.transactions_json", jsonArray.toString()).apply()
            Log.d("TransactionManager", "Transaction saved successfully: $newTx")
        } catch (e: Exception) {
            Log.e("TransactionManager", "Failed to save transaction: ${e.message}", e)
        }
    }

    fun getCustomCategories(context: Context): List<String> {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val defaultCategories = listOf("Dining", "Commute", "Subscriptions", "Utilities", "Other", "Income")
        return try {
            val jsonString = prefs.getString("flutter.categories_json", null)
            if (jsonString != null && jsonString.isNotEmpty()) {
                val jsonArray = JSONArray(jsonString)
                val list = mutableListOf<String>()
                for (i in 0 until jsonArray.length()) {
                    list.add(jsonArray.getString(i))
                }
                if (list.isNotEmpty()) list else defaultCategories
            } else {
                defaultCategories
            }
        } catch (e: Exception) {
            defaultCategories
        }
    }

    fun getCustomSources(context: Context): List<String> {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val defaultSources = listOf("Apple Wallet", "Bank Transfer", "Credit Card", "Cash")
        return try {
            val jsonString = prefs.getString("flutter.sources_json", null)
            if (jsonString != null && jsonString.isNotEmpty()) {
                val jsonArray = JSONArray(jsonString)
                val list = mutableListOf<String>()
                for (i in 0 until jsonArray.length()) {
                    list.add(jsonArray.getString(i))
                }
                if (list.isNotEmpty()) list else defaultSources
            } else {
                defaultSources
            }
        } catch (e: Exception) {
            defaultSources
        }
    }

    fun getGlobalCurrency(context: Context): String {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getString("flutter.currency_symbol", "₹") ?: "₹"
    }

    /**
     * Reads the user-assigned category colors from SharedPreferences.
     * Returns a map of category name → ARGB int color.
     */
    fun getCategoryColors(context: Context): Map<String, Int> {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return try {
            val json = prefs.getString("flutter.custom_category_colors", null) ?: return emptyMap()
            val obj = org.json.JSONObject(json)
            val map = mutableMapOf<String, Int>()
            obj.keys().forEach { key -> map[key] = obj.getInt(key) }
            map
        } catch (e: Exception) {
            emptyMap()
        }
    }

    /**
     * Reads the user-assigned source colors from SharedPreferences.
     * Returns a map of source name → ARGB int color.
     */
    fun getSourceColors(context: Context): Map<String, Int> {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return try {
            val json = prefs.getString("flutter.custom_source_colors", null) ?: return emptyMap()
            val obj = org.json.JSONObject(json)
            val map = mutableMapOf<String, Int>()
            obj.keys().forEach { key -> map[key] = obj.getInt(key) }
            map
        } catch (e: Exception) {
            emptyMap()
        }
    }

    /**
     * Reads the category visibilities from SharedPreferences.
     * Returns a map of category name -> visibility string (expense, income, both).
     */
    fun getCategoryVisibilities(context: Context): Map<String, String> {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        val defaultVisibilities = mutableMapOf(
            "Dining" to "expense",
            "Commute" to "expense",
            "Subscriptions" to "expense",
            "Utilities" to "expense",
            "Groceries" to "expense",
            "Shopping" to "expense",
            "Housing" to "expense",
            "Health" to "expense",
            "Travel" to "expense",
            "Investments" to "both",
            "Savings" to "both",
            "Salary" to "income",
            "Bonus" to "income",
            "Dividends" to "income",
            "Gift" to "both",
            "Other" to "both"
        )
        
        return try {
            val json = prefs.getString("flutter.category_visibilities_json", null)
            if (json != null) {
                val obj = org.json.JSONObject(json)
                obj.keys().forEach { key -> defaultVisibilities[key] = obj.getString(key) }
            }
            defaultVisibilities
        } catch (e: Exception) {
            defaultVisibilities
        }
    }
}
