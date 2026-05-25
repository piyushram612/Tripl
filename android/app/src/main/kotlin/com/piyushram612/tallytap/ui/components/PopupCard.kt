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
import java.util.Calendar
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// Obsidian Green Theme tokens for native compose
val GreenPrimary = Color(0xFF4EDEA3)
val GreenBgDark = Color(0xFF08100E)
val CardBgDark = Color(0xFF0D1612)
val BorderDark = Color(0xFF1D2F28)
val InactivePill = Color(0xFF1A2823)

fun Modifier.outerGlow(
    color: Color = GreenPrimary,
    radius: Dp = 16.dp,
    alpha: Float = 0.35f,
    cornerRadius: Dp = 100.dp
): Modifier = this.drawBehind {
    drawContext.canvas.nativeCanvas.apply {
        drawRoundRect(
            0f, 0f, size.width, size.height,
            cornerRadius.toPx(), cornerRadius.toPx(),
            android.graphics.Paint().apply {
                this.color = color.copy(alpha = alpha).toArgb()
                this.maskFilter = android.graphics.BlurMaskFilter(radius.toPx(), android.graphics.BlurMaskFilter.Blur.NORMAL)
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PopupCard(
    onClose: () -> Unit
) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE) }
    
    val currency = remember(prefs) {
        prefs.getString("flutter.currency_symbol", "₹") ?: "₹"
    }
    
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
    var isExpanded by remember { mutableStateOf(false) }
    val scale = remember { Animatable(0.85f) }

    // Input States
    var title by remember { mutableStateOf("") }
    var amount by remember { mutableStateOf(TextFieldValue("", selection = TextRange(0))) }
    var selectedCategory by remember { mutableStateOf(categories.firstOrNull() ?: "Dining") }
    var selectedSource by remember { mutableStateOf(sources.firstOrNull() ?: "Cash") }
    
    var transactionType by remember { mutableStateOf("EXPENSE") }
    var dateText by remember { mutableStateOf(SimpleDateFormat("dd MMM yyyy", Locale.US).format(Date())) }
    var timeText by remember { mutableStateOf(SimpleDateFormat("hh:mm a", Locale.US).format(Date())) }
    var paidTo by remember { mutableStateOf("") }
    var finishLater by remember { mutableStateOf(true) }
    var reminderDate by remember { mutableStateOf(SimpleDateFormat("dd.MM.yyyy", Locale.US).format(Date())) }
    var reminderTime by remember { mutableStateOf("09:00") }
    
    val isIncome = transactionType == "INCOME"

    val focusRequester = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current
    
    var showDatePicker by remember { mutableStateOf(false) }
    var showTimePicker by remember { mutableStateOf(false) }
    var showReminderDatePicker by remember { mutableStateOf(false) }
    var showReminderTimePicker by remember { mutableStateOf(false) }

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
                    .padding(top = 80.dp) // Fixed gap on top
                    .then(if (isExpanded) Modifier.fillMaxWidth() else Modifier.fillMaxWidth(0.92f))
                    .then(if (isExpanded) Modifier.fillMaxHeight() else Modifier.wrapContentHeight())
                    .animateContentSize()
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) { /* Catch clicks inside card */ }
                    .shadow(
                        elevation = 24.dp,
                        shape = RoundedCornerShape(32.dp),
                        clip = false,
                        ambientColor = Color.Black.copy(alpha = 0.5f),
                        spotColor = Color.Black.copy(alpha = 0.6f)
                    ),
                shape = RoundedCornerShape(32.dp),
                colors = CardDefaults.cardColors(
                    containerColor = CardBgDark
                ),
                border = BorderStroke(
                    width = 1.5.dp,
                    color = BorderDark
                )
            ) {
                Box(modifier = Modifier.then(if (isExpanded) Modifier.fillMaxSize() else Modifier.fillMaxWidth())) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .verticalScroll(rememberScrollState())
                            .imePadding()
                            .padding(start = 24.dp, end = 24.dp, top = 28.dp, bottom = 48.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        // 1. TITLE INPUT FIELD
                        BasicTextField(
                            value = title,
                            onValueChange = { title = it },
                            textStyle = TextStyle(
                                fontSize = 18.sp,
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
                                                fontSize = 18.sp,
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

                        // 2. AMOUNT INPUT FIELD
                        BasicTextField(
                            value = amount,
                            onValueChange = { newVal ->
                                val cleanText = newVal.text.filter { it.isDigit() || it == '.' }
                                amount = TextFieldValue(cleanText, selection = TextRange(cleanText.length))
                            },
                            textStyle = TextStyle(
                                fontSize = 48.sp,
                                fontWeight = FontWeight.W900,
                                color = Color.White.copy(alpha = 0.9f),
                                textAlign = TextAlign.Center
                            ),
                            decorationBox = { innerTextField ->
                                Box(
                                    contentAlignment = Alignment.Center,
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    if (amount.text.isEmpty()) {
                                        Text(
                                            text = "$currency 0",
                                            style = TextStyle(
                                                fontSize = 48.sp,
                                                fontWeight = FontWeight.W900,
                                                color = Color.White.copy(alpha = 0.4f),
                                                textAlign = TextAlign.Center
                                            )
                                        )
                                    } else {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Text(
                                                text = "$currency ",
                                                style = TextStyle(
                                                    fontSize = 48.sp,
                                                    fontWeight = FontWeight.W900,
                                                    color = Color.White.copy(alpha = 0.9f)
                                                )
                                            )
                                            innerTextField()
                                        }
                                    }
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

                        Spacer(modifier = Modifier.height(28.dp))

                        // 3. CATEGORY HEADER & CAPSULES ROW
                        SectionHeader("CATEGORY")
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .horizontalScroll(rememberScrollState()),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            categories.forEach { cat ->
                                ScrollableCategoryCapsule(
                                    label = cat,
                                    isSelected = (selectedCategory == cat),
                                    onClick = { selectedCategory = cat }
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(24.dp))

                        // 4. SOURCE HEADER & CAPSULES ROW
                        SectionHeader("SOURCE")
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .horizontalScroll(rememberScrollState()),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            sources.forEach { src ->
                                ScrollableCategoryCapsule(
                                    label = src,
                                    isSelected = (selectedSource == src),
                                    onClick = { selectedSource = src }
                                )
                            }
                        }

                        // EXPANDED CONTENT
                        AnimatedVisibility(visible = isExpanded) {
                            Column(modifier = Modifier.fillMaxWidth()) {
                                Spacer(modifier = Modifier.height(28.dp))
                                
                                // TYPE
                                SectionHeader("TYPE")
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(46.dp),
                                    horizontalArrangement = Arrangement.SpaceEvenly
                                ) {
                                    listOf("EXPENSE", "INCOME").forEach { type ->
                                        val isSelected = transactionType == type
                                        Box(
                                            modifier = Modifier
                                                .weight(1f)
                                                .fillMaxHeight()
                                                .clickable(
                                                    interactionSource = remember { MutableInteractionSource() },
                                                    indication = null
                                                ) { transactionType = type },
                                            contentAlignment = Alignment.Center
                                        ) {
                                            if (isSelected) {
                                                Box(
                                                    modifier = Modifier
                                                        .fillMaxSize()
                                                        .outerGlow(color = GreenPrimary, radius = 16.dp, alpha = 0.3f, cornerRadius = 14.dp)
                                                        .background(GreenPrimary, RoundedCornerShape(14.dp))
                                                )
                                            }
                                            Text(
                                                text = type,
                                                style = TextStyle(
                                                    fontSize = 12.sp,
                                                    fontWeight = FontWeight.W800,
                                                    letterSpacing = 1.0.sp,
                                                    color = if (isSelected) GreenBgDark else Color.White.copy(alpha = 0.6f)
                                                )
                                            )
                                        }
                                    }
                                }

                                Spacer(modifier = Modifier.height(24.dp))

                                // DATE & TIME
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                                ) {
                                    Box(modifier = Modifier.weight(1f)) {
                                        CustomInputField(
                                            label = "DATE",
                                            value = dateText,
                                            icon = Icons.Default.DateRange,
                                            onClick = { showDatePicker = true }
                                        )
                                    }
                                    Box(modifier = Modifier.weight(1f)) {
                                        CustomInputField(
                                            label = "TIME",
                                            value = timeText,
                                            icon = Icons.Default.Schedule,
                                            onClick = { showTimePicker = true }
                                        )
                                    }
                                }

                                Spacer(modifier = Modifier.height(24.dp))

                                // PAID TO / BY
                                CustomInputField(
                                    label = if (isIncome) "PAID BY" else "PAID TO",
                                    value = paidTo,
                                    onValueChange = { paidTo = it },
                                    icon = Icons.Default.Storefront,
                                    placeholder = "Enter name or organization"
                                )

                                Spacer(modifier = Modifier.height(24.dp))

                                // FINISH LATER CHECKBOX
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable(
                                            interactionSource = remember { MutableInteractionSource() },
                                            indication = null
                                        ) { finishLater = !finishLater },
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(24.dp)
                                            .background(if (finishLater) GreenPrimary else InactivePill, RoundedCornerShape(6.dp))
                                            .border(1.dp, if (finishLater) GreenPrimary else Color.Transparent, RoundedCornerShape(6.dp)),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        if (finishLater) {
                                            Icon(Icons.Outlined.Check, contentDescription = null, tint = GreenBgDark, modifier = Modifier.size(16.dp))
                                        }
                                    }
                                    Spacer(modifier = Modifier.width(14.dp))
                                    Text(
                                        text = if (isIncome) "Verify Receipt" else "Finish later",
                                        style = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.W600, color = Color.White)
                                    )
                                }

                                AnimatedVisibility(visible = finishLater) {
                                    Column {
                                        Spacer(modifier = Modifier.height(24.dp))
                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            horizontalArrangement = Arrangement.spacedBy(16.dp)
                                        ) {
                                            Box(modifier = Modifier.weight(1f)) {
                                                CustomInputField(
                                                    label = "REMINDER DATE",
                                                    value = reminderDate,
                                                    icon = Icons.Default.Notifications,
                                                    onClick = { showReminderDatePicker = true }
                                                )
                                            }
                                            Box(modifier = Modifier.weight(1f)) {
                                                CustomInputField(
                                                    label = "REMINDER TIME",
                                                    value = reminderTime,
                                                    icon = Icons.Default.Alarm,
                                                    onClick = { showReminderTimePicker = true }
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(36.dp))

                        // 5. MAIN LOG EXPENSE BUTTON CTA
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(56.dp)
                                .outerGlow(color = GreenPrimary, radius = 24.dp, alpha = 0.45f, cornerRadius = 100.dp)
                                .background(GreenPrimary, RoundedCornerShape(100.dp))
                                .clickable {
                                    if (amount.text.isNotBlank()) {
                                        saveTransactionToPrefs(
                                            context = context,
                                            titleText = if (title.isNotBlank()) title else "Quick Expense",
                                            amountText = amount.text,
                                            category = selectedCategory,
                                            source = selectedSource
                                        )
                                        Toast.makeText(context, "Logged: $currency${amount.text} to $selectedCategory", Toast.LENGTH_SHORT).show()
                                        onClose()
                                    } else {
                                        Toast.makeText(context, "Please enter an amount", Toast.LENGTH_SHORT).show()
                                    }
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "LOG EXPENSE",
                                style = TextStyle(
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.W900,
                                    letterSpacing = 0.5.sp,
                                    color = GreenBgDark
                                )
                            )
                        }
                    }
                    
                    // BOTTOM DRAG HANDLE FOR EXPANDING
                    Box(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .fillMaxWidth()
                            .height(48.dp)
                            .pointerInput(Unit) {
                                detectVerticalDragGestures { _, dragAmount ->
                                    if (dragAmount > 8) isExpanded = true
                                    else if (dragAmount < -8) isExpanded = false
                                }
                            }
                            .pointerInput(Unit) {
                                detectTapGestures(onDoubleTap = { isExpanded = !isExpanded })
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Box(
                            modifier = Modifier
                                .padding(bottom = 8.dp)
                                .width(40.dp)
                                .height(5.dp)
                                .background(Color.White.copy(alpha = 0.25f), CircleShape)
                        )
                    }
                }
            }
        }
    }
    
    // Pickers
    if (showDatePicker) {
        val datePickerState = rememberDatePickerState()
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let {
                        dateText = SimpleDateFormat("dd MMM yyyy", Locale.US).format(Date(it))
                    }
                    showDatePicker = false
                }) { Text("OK", color = GreenPrimary) }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text("Cancel", color = Color.White) }
            },
            colors = DatePickerDefaults.colors(containerColor = CardBgDark)
        ) {
            DatePicker(state = datePickerState, colors = DatePickerDefaults.colors(
                titleContentColor = GreenPrimary,
                headlineContentColor = Color.White,
                weekdayContentColor = Color.White,
                dayContentColor = Color.White,
                selectedDayContainerColor = GreenPrimary,
                selectedDayContentColor = GreenBgDark,
                todayContentColor = GreenPrimary,
                todayDateBorderColor = GreenPrimary
            ))
        }
    }
    
    if (showTimePicker) {
        val timePickerState = rememberTimePickerState()
        DatePickerDialog( // Using DatePickerDialog as a container for TimePicker
            onDismissRequest = { showTimePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    val cal = Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, timePickerState.hour)
                        set(Calendar.MINUTE, timePickerState.minute)
                    }
                    timeText = SimpleDateFormat("hh:mm a", Locale.US).format(cal.time)
                    showTimePicker = false
                }) { Text("OK", color = GreenPrimary) }
            },
            dismissButton = {
                TextButton(onClick = { showTimePicker = false }) { Text("Cancel", color = Color.White) }
            },
            colors = DatePickerDefaults.colors(containerColor = CardBgDark)
        ) {
            TimePicker(
                state = timePickerState,
                modifier = Modifier.padding(24.dp).align(Alignment.CenterHorizontally),
                colors = TimePickerDefaults.colors(
                    clockDialColor = InactivePill,
                    selectorColor = GreenPrimary,
                    clockDialSelectedContentColor = GreenBgDark,
                    clockDialUnselectedContentColor = Color.White,
                    timeSelectorSelectedContainerColor = GreenPrimary.copy(alpha = 0.2f),
                    timeSelectorSelectedContentColor = GreenPrimary,
                    timeSelectorUnselectedContainerColor = InactivePill,
                    timeSelectorUnselectedContentColor = Color.White
                )
            )
        }
    }

    if (showReminderDatePicker) {
        val datePickerState = rememberDatePickerState()
        DatePickerDialog(
            onDismissRequest = { showReminderDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let {
                        reminderDate = SimpleDateFormat("dd.MM.yyyy", Locale.US).format(Date(it))
                    }
                    showReminderDatePicker = false
                }) { Text("OK", color = GreenPrimary) }
            },
            dismissButton = {
                TextButton(onClick = { showReminderDatePicker = false }) { Text("Cancel", color = Color.White) }
            },
            colors = DatePickerDefaults.colors(containerColor = CardBgDark)
        ) {
            DatePicker(state = datePickerState, colors = DatePickerDefaults.colors(
                titleContentColor = GreenPrimary,
                headlineContentColor = Color.White,
                weekdayContentColor = Color.White,
                dayContentColor = Color.White,
                selectedDayContainerColor = GreenPrimary,
                selectedDayContentColor = GreenBgDark,
                todayContentColor = GreenPrimary,
                todayDateBorderColor = GreenPrimary
            ))
        }
    }
    
    if (showReminderTimePicker) {
        val timePickerState = rememberTimePickerState()
        DatePickerDialog(
            onDismissRequest = { showReminderTimePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    val cal = Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, timePickerState.hour)
                        set(Calendar.MINUTE, timePickerState.minute)
                    }
                    reminderTime = SimpleDateFormat("hh:mm a", Locale.US).format(cal.time)
                    showReminderTimePicker = false
                }) { Text("OK", color = GreenPrimary) }
            },
            dismissButton = {
                TextButton(onClick = { showReminderTimePicker = false }) { Text("Cancel", color = Color.White) }
            },
            colors = DatePickerDefaults.colors(containerColor = CardBgDark)
        ) {
            TimePicker(
                state = timePickerState,
                modifier = Modifier.padding(24.dp).align(Alignment.CenterHorizontally),
                colors = TimePickerDefaults.colors(
                    clockDialColor = InactivePill,
                    selectorColor = GreenPrimary,
                    clockDialSelectedContentColor = GreenBgDark,
                    clockDialUnselectedContentColor = Color.White,
                    timeSelectorSelectedContainerColor = GreenPrimary.copy(alpha = 0.2f),
                    timeSelectorSelectedContentColor = GreenPrimary,
                    timeSelectorUnselectedContainerColor = InactivePill,
                    timeSelectorUnselectedContentColor = Color.White
                )
            )
        }
    }
}

@Composable
fun SectionHeader(text: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Start) {
        Text(
            text = text,
            style = TextStyle(
                fontSize = 11.sp,
                fontWeight = FontWeight.W800,
                letterSpacing = 1.0.sp,
                color = GreenPrimary.copy(alpha = 0.8f)
            )
        )
    }
    Spacer(modifier = Modifier.height(12.dp))
}

@Composable
fun CustomInputField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit = {},
    icon: ImageVector? = null,
    placeholder: String = "",
    onClick: (() -> Unit)? = null
) {
    var isFocused by remember { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = label,
            style = TextStyle(
                fontSize = 11.sp,
                fontWeight = FontWeight.W800,
                letterSpacing = 1.0.sp,
                color = GreenPrimary.copy(alpha = 0.8f)
            )
        )
        Spacer(modifier = Modifier.height(10.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .then(if (isFocused || (onClick != null && value.isNotEmpty())) Modifier.outerGlow(color = GreenPrimary, radius = 8.dp, alpha = 0.25f, cornerRadius = 14.dp) else Modifier)
                .background(InactivePill, RoundedCornerShape(14.dp))
                .border(1.dp, if (isFocused || (onClick != null && value.isNotEmpty())) GreenPrimary else Color.Transparent, RoundedCornerShape(14.dp))
                .clickable(
                    enabled = onClick != null,
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null
                ) { onClick?.invoke() }
                .padding(horizontal = 16.dp),
            contentAlignment = Alignment.CenterStart
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (icon != null) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = if (isFocused || (onClick != null && value.isNotEmpty())) GreenPrimary else Color.White.copy(alpha = 0.4f),
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                }
                if (onClick != null) {
                    Text(
                        text = value.ifEmpty { placeholder },
                        style = TextStyle(
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (value.isEmpty()) Color.White.copy(alpha = 0.3f) else Color.White
                        ),
                        modifier = Modifier.fillMaxWidth()
                    )
                } else {
                    BasicTextField(
                        value = value,
                        onValueChange = onValueChange,
                        textStyle = TextStyle(
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color.White
                        ),
                        modifier = Modifier
                            .fillMaxWidth()
                            .onFocusChanged { isFocused = it.isFocused },
                        decorationBox = { innerTextField ->
                            if (value.isEmpty() && placeholder.isNotEmpty()) {
                                Text(
                                    text = placeholder,
                                    style = TextStyle(
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.SemiBold,
                                        color = Color.White.copy(alpha = 0.3f)
                                    )
                                )
                            }
                            innerTextField()
                        }
                    )
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
            .height(42.dp)
            .then(if (isSelected) Modifier.outerGlow(color = GreenPrimary, radius = 12.dp, alpha = 0.35f, cornerRadius = 100.dp) else Modifier)
            .clip(RoundedCornerShape(100.dp))
            .background(if (isSelected) GreenPrimary.copy(alpha = 0.15f) else InactivePill)
            .border(
                width = 1.0.dp,
                color = if (isSelected) GreenPrimary else Color.Transparent,
                shape = RoundedCornerShape(100.dp)
            )
            .clickable { onClick() }
            .padding(horizontal = 20.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            style = TextStyle(
                fontSize = 13.sp,
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
