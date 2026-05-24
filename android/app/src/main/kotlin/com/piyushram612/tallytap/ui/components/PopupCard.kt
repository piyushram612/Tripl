package com.piyushram612.tallytap.ui.components

import android.content.Context
import android.util.Log
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// Obsidian Green Theme tokens for native compose
val GreenPrimary = Color(0xFF4EDEA3)
val GreenBgDark = Color(0xFF08100E)
val CardBgDark = Color(0xFF0D1612)
val BorderDark = Color(0xFF1D2F28)
val InactivePill = Color(0xFF1A2823)

@Composable
fun PopupCard(
    onClose: () -> Unit
) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE) }
    
    // Load categories dynamically from SharedPreferences, bulletproof fallback to defaults if empty
    val categories = remember(prefs) {
        val jsonStr = prefs.getString("flutter.categories_json", null)
        val loadedList = if (jsonStr != null && jsonStr.isNotEmpty()) {
            try {
                val arr = JSONArray(jsonStr)
                List(arr.length()) { arr.getString(it) }
            } catch (e: Exception) {
                emptyList()
            }
        } else {
            emptyList()
        }
        
        if (loadedList.isEmpty()) {
            listOf("Dining", "Commute", "Subscriptions", "Utilities", "Groceries", "Shopping", "Housing", "Health", "Travel", "Other")
        } else {
            loadedList
        }
    }

    // Load payment sources dynamically from SharedPreferences, bulletproof fallback to defaults if empty
    val sources = remember(prefs) {
        val jsonStr = prefs.getString("flutter.sources_json", null)
        val loadedList = if (jsonStr != null && jsonStr.isNotEmpty()) {
            try {
                val arr = JSONArray(jsonStr)
                List(arr.length()) { arr.getString(it) }
            } catch (e: Exception) {
                emptyList()
            }
        } else {
            emptyList()
        }
        
        if (loadedList.isEmpty()) {
            listOf("Cash", "Bank Account", "Credit Card")
        } else {
            loadedList
        }
    }

    var visible by remember { mutableStateOf(false) }
    val scale = remember { Animatable(0.85f) }

    // Input States
    var title by remember { mutableStateOf("") }
    var amount by remember { mutableStateOf(TextFieldValue("", selection = TextRange(0))) }
    var selectedCategory by remember { mutableStateOf(categories.firstOrNull() ?: "Dining") }
    var selectedSource by remember { mutableStateOf(sources.firstOrNull() ?: "Cash") }

    val focusRequester = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current

    LaunchedEffect(Unit) {
        visible = true
        scale.animateTo(
            targetValue = 1.0f,
            animationSpec = tween(durationMillis = 280)
        )
        // Request autofocus on Amount field first to reduce logging friction
        focusRequester.requestFocus()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onClose() },
        contentAlignment = Alignment.TopCenter // Aligns popup card at the Top of the screen!
    ) {
        AnimatedVisibility(
            visible = visible,
            enter = fadeIn(animationSpec = tween(250)) + scaleIn(initialScale = 0.85f, animationSpec = tween(280))
        ) {
            Card(
                modifier = Modifier
                    .padding(top = 80.dp) // Positions the dynamic island exactly in the top 25% of the screen!
                    .width(320.dp)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) { /* Catch clicks inside card */ }
                    .shadow(
                        elevation = 24.dp,
                        shape = RoundedCornerShape(28.dp),
                        clip = false,
                        ambientColor = Color.Black.copy(alpha = 0.4f),
                        spotColor = Color.Black.copy(alpha = 0.5f)
                    ),
                shape = RoundedCornerShape(28.dp),
                colors = CardDefaults.cardColors(
                    containerColor = CardBgDark
                ),
                border = BorderStroke(
                    width = 1.5.dp,
                    color = BorderDark
                )
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp, vertical = 28.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    // 1. TITLE INPUT FIELD
                    BasicTextField(
                        value = title,
                        onValueChange = { title = it },
                        textStyle = TextStyle(
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White,
                            textAlign = TextAlign.Center
                        ),
                        decorationBox = { innerTextField ->
                            Box(
                                contentAlignment = Alignment.Center,
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                if (title.isEmpty()) {
                                    Text(
                                        text = "Title",
                                        style = TextStyle(
                                            fontSize = 20.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = Color.White.copy(alpha = 0.6f),
                                            textAlign = TextAlign.Center
                                        )
                                    )
                                }
                                innerTextField()
                            }
                        },
                        keyboardOptions = KeyboardOptions(
                            imeAction = ImeAction.Next
                        ),
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(modifier = Modifier.height(10.dp))

                    // 2. AMOUNT INPUT FIELD (Large dynamic size)
                    BasicTextField(
                        value = amount,
                        onValueChange = { newVal ->
                            // Allow only numeric decimals
                            val cleanText = newVal.text.filter { it.isDigit() || it == '.' }
                            amount = TextFieldValue(cleanText, selection = TextRange(cleanText.length))
                        },
                        textStyle = TextStyle(
                            fontSize = 44.sp,
                            fontWeight = FontWeight.W900,
                            color = Color.White.copy(alpha = 0.85f),
                            textAlign = TextAlign.Center
                        ),
                        decorationBox = { innerTextField ->
                            Box(
                                contentAlignment = Alignment.Center,
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                if (amount.text.isEmpty()) {
                                    Text(
                                        text = "Amount",
                                        style = TextStyle(
                                            fontSize = 44.sp,
                                            fontWeight = FontWeight.W900,
                                            color = Color.White.copy(alpha = 0.35f),
                                            textAlign = TextAlign.Center
                                        )
                                    )
                                }
                                innerTextField()
                            }
                        },
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Decimal,
                            imeAction = ImeAction.Done
                        ),
                        keyboardActions = KeyboardActions(
                            onDone = { focusManager.clearFocus() }
                        ),
                        singleLine = true,
                        modifier = Modifier
                            .fillMaxWidth()
                            .focusRequester(focusRequester)
                    )

                    Spacer(modifier = Modifier.height(24.dp))

                    // 3. CATEGORY HEADER & CAPSULES ROW
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Start
                    ) {
                        Text(
                          text = "CATEGORY",
                          style = TextStyle(
                              fontSize = 11.sp,
                              fontWeight = FontWeight.W800,
                              letterSpacing = 1.0.sp,
                              color = GreenPrimary.copy(alpha = 0.8f)
                          )
                        )
                    }
                    Spacer(modifier = Modifier.height(10.dp))
                    
                    // Horizontally scrollable category capsules row
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        categories.forEach { cat ->
                            ScrollableCategoryCapsule(
                                label = cat,
                                isSelected = (selectedCategory == cat),
                                onClick = { selectedCategory = cat }
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(20.dp))

                    // 4. SOURCE HEADER & CAPSULES ROW
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Start
                    ) {
                        Text(
                            text = "SOURCE",
                            style = TextStyle(
                                fontSize = 11.sp,
                                fontWeight = FontWeight.W800,
                                letterSpacing = 1.0.sp,
                                color = GreenPrimary.copy(alpha = 0.8f)
                            )
                        )
                    }
                    Spacer(modifier = Modifier.height(10.dp))
                    
                    // Horizontally scrollable source capsules row
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        sources.forEach { src ->
                            ScrollableCategoryCapsule(
                                label = src,
                                isSelected = (selectedSource == src),
                                onClick = { selectedSource = src }
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(28.dp))

                    // 5. MAIN LOG EXPENSE BUTTON CTA
                    Button(
                        onClick = {
                            if (amount.text.isNotBlank()) {
                                saveTransactionToPrefs(
                                    context = context,
                                    titleText = if (title.isNotBlank()) title else "Quick Expense",
                                    amountText = amount.text,
                                    category = selectedCategory,
                                    source = selectedSource
                                )
                                Toast.makeText(context, "Logged: \$${amount.text} to $selectedCategory", Toast.LENGTH_SHORT).show()
                                onClose()
                            } else {
                                Toast.makeText(context, "Please enter an amount", Toast.LENGTH_SHORT).show()
                            }
                        },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = GreenPrimary,
                            contentColor = GreenBgDark
                        ),
                        shape = RoundedCornerShape(100.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp),
                        elevation = ButtonDefaults.buttonElevation(defaultElevation = 0.dp)
                    ) {
                        Text(
                            text = "LOG EXPENSE",
                            style = TextStyle(
                                fontSize = 14.sp,
                                fontWeight = FontWeight.W900,
                                letterSpacing = 0.5.sp
                            )
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun ScrollableCategoryCapsule(
    label: String,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .height(38.dp)
            .clip(RoundedCornerShape(100.dp))
            .background(if (isSelected) Color.Transparent else InactivePill)
            .border(
                width = 1.0.dp,
                color = if (isSelected) GreenPrimary else Color.Transparent,
                shape = RoundedCornerShape(100.dp)
            )
            .clickable { onClick() }
            .padding(horizontal = 18.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            style = TextStyle(
                fontSize = 12.sp,
                fontWeight = FontWeight.W700,
                color = if (isSelected) GreenPrimary else Color.White.copy(alpha = 0.8f)
            ),
            maxLines = 1
        )
    }
}

private fun saveTransactionToPrefs(
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
        Log.d("PopupCard", "Transaction saved successfully: $newTx")
    } catch (e: Exception) {
        Log.e("PopupCard", "Failed to save transaction: ${e.message}", e)
    }
}
