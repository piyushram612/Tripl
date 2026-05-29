package com.piyushram612.tallytap.ui.components

import android.content.Context
import android.content.Intent
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
import androidx.compose.ui.unit.sp
import com.piyushram612.tallytap.ui.components.core.*
import com.piyushram612.tallytap.utils.TransactionManager
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
    
    val currency = remember(context) { TransactionManager.getGlobalCurrency(context) }
    val categories = remember(context) { TransactionManager.getCustomCategories(context) }
    val sources = remember(context) { TransactionManager.getCustomSources(context) }

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
            .imePadding()
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
                    .padding(top = 56.dp) // Shifted a tiny bit lower for premium gap
                    .then(if (isExpanded) Modifier.fillMaxWidth() else Modifier.fillMaxWidth(0.96f)) // Made a bit wider
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
                            .padding(start = 24.dp, end = 24.dp, top = 16.dp, bottom = 48.dp), // Reduced height/top padding
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

                        Spacer(modifier = Modifier.height(6.dp))

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

                        Spacer(modifier = Modifier.height(16.dp))

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

                        Spacer(modifier = Modifier.height(16.dp))

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
                                Spacer(modifier = Modifier.height(16.dp))
                                
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

                                Spacer(modifier = Modifier.height(16.dp))

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

                                Spacer(modifier = Modifier.height(16.dp))

                                // PAID TO / BY
                                CustomInputField(
                                    label = if (isIncome) "PAID BY" else "PAID TO",
                                    value = paidTo,
                                    onValueChange = { paidTo = it },
                                    icon = Icons.Default.Storefront,
                                    placeholder = "Enter name or organization"
                                )

                                Spacer(modifier = Modifier.height(16.dp))

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
                                        Spacer(modifier = Modifier.height(16.dp))
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

                        Spacer(modifier = Modifier.height(24.dp))

                        // 5. MAIN LOG EXPENSE BUTTON CTA
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(56.dp)
                                .outerGlow(color = GreenPrimary, radius = 24.dp, alpha = 0.45f, cornerRadius = 100.dp)
                                .background(GreenPrimary, RoundedCornerShape(100.dp))
                                .clickable {
                                    if (amount.text.isNotBlank()) {
                                        TransactionManager.saveTransactionToPrefs(
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

                    // OPEN IN APP BUTTON (INCREASED SIZE)
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .padding(top = 16.dp, end = 16.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(BorderDark)
                            .clickable {
                                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                                    flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP
                                    putExtra("navigate", "create_transaction")
                                }
                                context.startActivity(launchIntent)
                                onClose()
                            }
                            .padding(horizontal = 12.dp, vertical = 8.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.OpenInNew,
                                contentDescription = "Open in app",
                                tint = GreenPrimary,
                                modifier = Modifier.size(14.dp)
                            )
                            Text(
                                text = "Open in App",
                                style = TextStyle(
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White.copy(alpha = 0.9f)
                                )
                            )
                        }
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

