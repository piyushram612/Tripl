package com.piyushram612.tallytap.utils

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
        source: String
    ) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val transactionsJson = prefs.getString("flutter.transactions_json", "[]") ?: "[]"
            val jsonArray = JSONArray(transactionsJson)

            val newTx = JSONObject().apply {
                put("id", UUID.randomUUID().toString())
                put("amount", amountText.toDoubleOrNull() ?: 0.0)
                put("merchant", titleText)

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
        return prefs.getString("flutter.currency_symbol", "$") ?: "$"
    }
}
