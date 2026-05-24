package com.piyushram612.tallytap.ui.components

import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AccountBalance
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Fastfood
import androidx.compose.material.icons.rounded.LocalGasStation
import androidx.compose.material.icons.rounded.Money
import androidx.compose.material.icons.rounded.QrCode
import androidx.compose.material.icons.rounded.Receipt
import androidx.compose.material.icons.rounded.ShoppingBag
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.sp
import com.piyushram612.tallytap.ui.theme.*
import kotlin.math.roundToInt
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import android.app.DatePickerDialog
import android.app.TimePickerDialog
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.gestures.detectTapGestures
import java.util.Calendar
import java.text.SimpleDateFormat
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PopupCard(
    onClose: () -> Unit
) {
    val context = LocalContext.current
    var visible by remember { mutableStateOf(false) }
    
    val dragOffsetY = remember { Animatable(0f) }
    val coroutineScope = rememberCoroutineScope()
    
    // Input Fields States
    var amount by remember { mutableStateOf(TextFieldValue("0", selection = TextRange(1))) }
    var note by remember { mutableStateOf("") }
    var selectedCategory by remember { mutableStateOf("Food") }
    var selectedSource by remember { mutableStateOf("UPI") }
    
    // New Expanded States
    var isExpanded by remember { mutableStateOf(false) }
    var isIncome by remember { mutableStateOf(false) }
    var partyName by remember { mutableStateOf("") }
    var transactionDate by remember { mutableStateOf(Calendar.getInstance()) }

    // Animation states
    val cardPaddingTop by animateDpAsState(if (isExpanded) 0.dp else 72.dp)
    val cardPaddingHorizontal by animateDpAsState(if (isExpanded) 0.dp else 16.dp)
    val cardCornerRadius by animateDpAsState(if (isExpanded) 0.dp else 28.dp)
    
    // M3 Picker States
    var showDatePicker by remember { mutableStateOf(false) }
    var showTimePicker by remember { mutableStateOf(false) }
    val datePickerState = rememberDatePickerState(
        initialSelectedDateMillis = transactionDate.timeInMillis
    )
    val timePickerState = rememberTimePickerState(
        initialHour = transactionDate.get(Calendar.HOUR_OF_DAY),
        initialMinute = transactionDate.get(Calendar.MINUTE)
    )

    val focusRequester = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current
    val darkTheme = isSystemInDarkTheme()
    
    val rootBackgroundColor by androidx.compose.animation.animateColorAsState(
        if (isExpanded) {
            if (darkTheme) CardBgDark else CardBgLight
        } else {
            Color.Transparent
        }
    )

    // Slide/Fade-in triggering
    LaunchedEffect(Unit) {
        visible = true
        // Request autofocus on currency input after a slight UI buffer
        delay(100)
        try {
            focusRequester.requestFocus()
        } catch (_: Exception) {}
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(rootBackgroundColor)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { 
                // Tap outside card -> Dismiss
                onClose()
            },
        contentAlignment = Alignment.TopCenter
    ) {
        AnimatedVisibility(
            visible = visible,
            enter = fadeIn(animationSpec = tween(250)) + slideInVertically(initialOffsetY = { -it }, animationSpec = tween(280))
        ) {
            Card(
                modifier = Modifier
                    .offset { IntOffset(0, dragOffsetY.value.roundToInt()) }
                    .fillMaxWidth()
                    .then(if (isExpanded) Modifier.fillMaxHeight() else Modifier)
                    .padding(top = cardPaddingTop, start = cardPaddingHorizontal, end = cardPaddingHorizontal)
                    .pointerInput(Unit) {
                        detectVerticalDragGestures(
                            onDragEnd = {
                                coroutineScope.launch {
                                    if (dragOffsetY.value > 100f && !isExpanded) {
                                        isExpanded = true
                                    } else if (dragOffsetY.value < -100f && isExpanded) {
                                        isExpanded = false
                                    }
                                    dragOffsetY.animateTo(0f, tween(300))
                                }
                            },
                            onVerticalDrag = { change, dragAmount ->
                                change.consume()
                                coroutineScope.launch {
                                    dragOffsetY.snapTo(dragOffsetY.value + dragAmount)
                                }
                            }
                        )
                    }
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) { /* Catch taps inside card to prevent dismissal */ }
                    .shadow(
                        elevation = 32.dp,
                        shape = RoundedCornerShape(cardCornerRadius),
                        clip = false,
                        ambientColor = if (darkTheme) PrimaryGreen.copy(alpha = 0.2f) else Color.Black.copy(alpha = 0.4f),
                        spotColor = if (darkTheme) PrimaryGreen.copy(alpha = 0.4f) else Color.Black.copy(alpha = 0.5f)
                    ),
                shape = RoundedCornerShape(cardCornerRadius),
                colors = CardDefaults.cardColors(
                    containerColor = if (darkTheme) CardBgDark else CardBgLight
                ),
                border = BorderStroke(
                    width = 1.5.dp,
                    brush = Brush.linearGradient(
                        colors = if (darkTheme) {
                            listOf(PrimaryGreen.copy(alpha = 0.9f), PrimaryGreen.copy(alpha = 0.2f))
                        } else {
                            listOf(BorderLight, Color(0xFFF3F4F6))
                        }
                    )
                )
            ) {
                val sysBars = WindowInsets.systemBars.asPaddingValues()
                val innerTopPadding by animateDpAsState(if (isExpanded) 24.dp + sysBars.calculateTopPadding() else 24.dp)
                val innerBottomPadding by animateDpAsState(if (isExpanded) 24.dp + sysBars.calculateBottomPadding() else 24.dp)
                
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = innerTopPadding, bottom = innerBottomPadding, start = 24.dp, end = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    // Header Bar
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(modifier = Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(10.dp)
                                    .clip(CircleShape)
                                    .background(PrimaryGreen)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "TallyTap Triggered",
                                style = MaterialTheme.typography.bodyMedium.copy(
                                    fontWeight = FontWeight.W800,
                                    letterSpacing = 0.5.sp,
                                    color = if (darkTheme) Color.White else TextLight
                                ),
                                maxLines = 1,
                                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(20.dp))

                    // Autofocused Currency Input (Frictionless logging)
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.Start,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = "₹",
                            style = TextStyle(
                                fontSize = 42.sp,
                                fontWeight = FontWeight.W900,
                                color = PrimaryGreen
                            )
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        
                        BasicTextField(
                            value = amount,
                            onValueChange = { newVal: TextFieldValue ->
                                val cleanText = newVal.text.filter { it.isDigit() }
                                if (cleanText.isEmpty()) {
                                    amount = TextFieldValue("0", selection = TextRange(1))
                                } else {
                                    val unformatted = if (cleanText.length > 1 && cleanText.startsWith("0")) {
                                        cleanText.substring(1)
                                    } else {
                                        cleanText
                                    }
                                    val cursorOffset = if (cleanText.length > 1 && cleanText.startsWith("0")) {
                                        (newVal.selection.start - 1).coerceAtLeast(0)
                                    } else {
                                        newVal.selection.start
                                    }.coerceIn(0, unformatted.length)
                                    amount = TextFieldValue(unformatted, selection = TextRange(cursorOffset))
                                }
                            },
                            modifier = Modifier.weight(1f).focusRequester(focusRequester),
                            visualTransformation = IndianCurrencyVisualTransformation(),
                            textStyle = TextStyle(
                                fontSize = 42.sp,
                                fontWeight = FontWeight.W900,
                                color = if (darkTheme) Color.White else TextLight,
                                textAlign = TextAlign.Start
                            ),
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Number,
                                imeAction = ImeAction.Next
                            ),
                            keyboardActions = KeyboardActions(
                                onNext = { focusManager.moveFocus(androidx.compose.ui.focus.FocusDirection.Down) }
                            ),
                            singleLine = true
                        )
                    }

                    Spacer(modifier = Modifier.height(20.dp))

                    // Categories Scrollable Row
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.Start
                    ) {
                        PillChip("Food", Icons.Rounded.Fastfood, selectedCategory == "Food", darkTheme) {
                            selectedCategory = "Food"
                        }
                        PillChip("Fuel", Icons.Rounded.LocalGasStation, selectedCategory == "Fuel", darkTheme) {
                            selectedCategory = "Fuel"
                        }
                        PillChip("Shop", Icons.Rounded.ShoppingBag, selectedCategory == "Shop", darkTheme) {
                            selectedCategory = "Shop"
                        }
                        PillChip("Bills", Icons.Rounded.Receipt, selectedCategory == "Bills", darkTheme) {
                            selectedCategory = "Bills"
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // Source Scrollable Row
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.Start
                    ) {
                        PillChip("UPI", Icons.Rounded.QrCode, selectedSource == "UPI", darkTheme) {
                            selectedSource = "UPI"
                        }
                        PillChip("Bank", Icons.Rounded.AccountBalance, selectedSource == "Bank", darkTheme) {
                            selectedSource = "Bank"
                        }
                        PillChip("Cash", Icons.Rounded.Money, selectedSource == "Cash", darkTheme) {
                            selectedSource = "Cash"
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // --- Expanded Fields ---
                    AnimatedVisibility(visible = isExpanded) {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            // Transaction Type Segmented Control
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(48.dp)
                                    .clip(RoundedCornerShape(24.dp))
                                    .background(if (darkTheme) Color(0xFF141D19) else Color(0xFFF3F4F6))
                                    .padding(4.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .fillMaxHeight()
                                        .clip(RoundedCornerShape(20.dp))
                                        .background(if (!isIncome) (if (darkTheme) Color(0xFF0D251A) else PrimaryGreen.copy(alpha=0.15f)) else Color.Transparent)
                                        .clickable { isIncome = false },
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text("Expense", color = if (!isIncome) PrimaryGreen else TextGray, fontWeight = FontWeight.Bold)
                                }
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .fillMaxHeight()
                                        .clip(RoundedCornerShape(20.dp))
                                        .background(if (isIncome) (if (darkTheme) Color(0xFF0D251A) else PrimaryGreen.copy(alpha=0.15f)) else Color.Transparent)
                                        .clickable { isIncome = true },
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text("Income", color = if (isIncome) PrimaryGreen else TextGray, fontWeight = FontWeight.Bold)
                                }
                            }
                            Spacer(modifier = Modifier.height(16.dp))
                            
                            // Party Name
                            OutlinedTextField(
                                value = partyName,
                                onValueChange = { partyName = it },
                                placeholder = { Text(if (isIncome) "Received from" else "Paid to", style = TextStyle(fontSize = 13.sp, color = TextGray)) },
                                textStyle = TextStyle(fontSize = 13.sp, color = if (darkTheme) Color.White else TextLight),
                                shape = RoundedCornerShape(12.dp),
                                modifier = Modifier.fillMaxWidth(),
                                singleLine = true,
                                colors = OutlinedTextFieldDefaults.colors(
                                    focusedBorderColor = PrimaryGreen,
                                    unfocusedBorderColor = if (darkTheme) BorderDark else BorderLight,
                                    focusedContainerColor = if (darkTheme) Color(0xFF141D19) else Color(0xFFF9FAFB),
                                    unfocusedContainerColor = if (darkTheme) Color(0xFF141D19) else Color(0xFFF9FAFB)
                                )
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            
                            // Date/Time Side-by-Side
                            val dateFormatter = SimpleDateFormat("MMM dd, yyyy", Locale.getDefault())
                            val timeFormatter = SimpleDateFormat("hh:mm a", Locale.getDefault())
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                Box(modifier = Modifier.weight(1f).clickable { showDatePicker = true }) {
                                    OutlinedTextField(
                                        value = dateFormatter.format(transactionDate.time),
                                        onValueChange = {},
                                        readOnly = true,
                                        enabled = false,
                                        textStyle = TextStyle(fontSize = 13.sp, color = if (darkTheme) Color.White else TextLight),
                                        shape = RoundedCornerShape(12.dp),
                                        modifier = Modifier.fillMaxWidth(),
                                        colors = OutlinedTextFieldDefaults.colors(
                                            disabledTextColor = if (darkTheme) Color.White else TextLight,
                                            disabledBorderColor = if (darkTheme) BorderDark else BorderLight,
                                            disabledContainerColor = if (darkTheme) Color(0xFF141D19) else Color(0xFFF9FAFB)
                                        )
                                    )
                                }
                                Box(modifier = Modifier.weight(1f).clickable { showTimePicker = true }) {
                                    OutlinedTextField(
                                        value = timeFormatter.format(transactionDate.time),
                                        onValueChange = {},
                                        readOnly = true,
                                        enabled = false,
                                        textStyle = TextStyle(fontSize = 13.sp, color = if (darkTheme) Color.White else TextLight),
                                        shape = RoundedCornerShape(12.dp),
                                        modifier = Modifier.fillMaxWidth(),
                                        colors = OutlinedTextFieldDefaults.colors(
                                            disabledTextColor = if (darkTheme) Color.White else TextLight,
                                            disabledBorderColor = if (darkTheme) BorderDark else BorderLight,
                                            disabledContainerColor = if (darkTheme) Color(0xFF141D19) else Color(0xFFF9FAFB)
                                        )
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.height(20.dp))
                        }
                    }
                    // --- End Expanded Fields ---

                    Spacer(modifier = Modifier.height(8.dp))

                    // Note Field + Checkmark Log Button
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        OutlinedTextField(
                            value = note,
                            onValueChange = { note = it },
                            placeholder = { 
                                Text(
                                    "Add quick note...",
                                    style = TextStyle(fontSize = 13.sp, color = TextGray)
                                )
                            },
                            textStyle = TextStyle(fontSize = 13.sp, color = if (darkTheme) Color.White else TextLight),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.weight(1f),
                            singleLine = true,
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = PrimaryGreen,
                                unfocusedBorderColor = if (darkTheme) BorderDark else BorderLight,
                                focusedContainerColor = if (darkTheme) Color(0xFF141D19) else Color(0xFFF9FAFB),
                                unfocusedContainerColor = if (darkTheme) Color(0xFF141D19) else Color(0xFFF9FAFB)
                            ),
                            keyboardOptions = KeyboardOptions(
                                imeAction = ImeAction.Done
                            ),
                            keyboardActions = KeyboardActions(
                                onDone = {
                                    focusManager.clearFocus()
                                    // Double back tap workflow simulation save
                                    Toast.makeText(context, "Log Successful: ₹${amount.text} ($selectedCategory)", Toast.LENGTH_SHORT).show()
                                    onClose()
                                }
                            )
                        )

                        Spacer(modifier = Modifier.width(12.dp))

                        // Round Checkmark CTA
                        Box(
                            modifier = Modifier
                                .size(56.dp)
                                .clip(CircleShape)
                                .background(PrimaryGreen)
                                .clickable {
                                    Toast.makeText(context, "Log Successful: ₹${amount.text} ($selectedCategory)", Toast.LENGTH_SHORT).show()
                                    onClose()
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Rounded.Check,
                                contentDescription = "Log Trigger",
                                tint = Color.White,
                                modifier = Modifier.size(28.dp)
                            )
                        }
                    }
                    
                    Spacer(modifier = Modifier.height(24.dp))
                    
                    // Drag Handle
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 12.dp)
                            .pointerInput(Unit) {
                                detectTapGestures(
                                    onDoubleTap = {
                                        isExpanded = !isExpanded
                                    }
                                )
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Box(
                            modifier = Modifier
                                .width(40.dp)
                                .height(4.dp)
                                .clip(CircleShape)
                                .background(if (darkTheme) Color.White.copy(alpha = 0.2f) else Color.Black.copy(alpha = 0.2f))
                        )
                    }
                }
            }
        }
    }
    
    // M3 Dialogs
    if (showDatePicker) {
        androidx.compose.material3.DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    showDatePicker = false
                    datePickerState.selectedDateMillis?.let {
                        val cal = Calendar.getInstance().apply { timeInMillis = it }
                        transactionDate.set(Calendar.YEAR, cal.get(Calendar.YEAR))
                        transactionDate.set(Calendar.MONTH, cal.get(Calendar.MONTH))
                        transactionDate.set(Calendar.DAY_OF_MONTH, cal.get(Calendar.DAY_OF_MONTH))
                    }
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text("Cancel") }
            }
        ) {
            DatePicker(state = datePickerState)
        }
    }
    
    if (showTimePicker) {
        AlertDialog(
            onDismissRequest = { showTimePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    showTimePicker = false
                    transactionDate.set(Calendar.HOUR_OF_DAY, timePickerState.hour)
                    transactionDate.set(Calendar.MINUTE, timePickerState.minute)
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { showTimePicker = false }) { Text("Cancel") }
            },
            text = {
                TimePicker(state = timePickerState)
            }
        )
    }
}

@Composable
fun PillChip(
    label: String,
    icon: ImageVector,
    isSelected: Boolean,
    darkTheme: Boolean,
    onClick: () -> Unit
) {
    val bgColor = when {
        isSelected -> if (darkTheme) Color(0xFF0D251A) else PrimaryGreen.copy(alpha = 0.15f)
        darkTheme -> Color(0xFF202A26)
        else -> Color(0xFFF3F4F6)
    }
    
    val contentColor = when {
        isSelected -> if (darkTheme) PrimaryGreen else PrimaryGreen
        darkTheme -> Color.White.copy(alpha = 0.8f)
        else -> Color.Black.copy(alpha = 0.6f)
    }

    val borderColor = when {
        isSelected -> PrimaryGreen
        darkTheme -> Color(0xFF2E3834)
        else -> Color(0xFFE5E7EB)
    }

    Row(
        modifier = Modifier
            .padding(end = 8.dp)
            .height(38.dp)
            .clip(RoundedCornerShape(19.dp))
            .background(bgColor)
            .border(BorderStroke(1.dp, borderColor), RoundedCornerShape(19.dp))
            .clickable { onClick() }
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            modifier = Modifier.size(16.dp),
            tint = contentColor
        )
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            text = label,
            style = TextStyle(
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = contentColor
            )
        )
    }
}

class IndianCurrencyVisualTransformation : VisualTransformation {
    override fun filter(text: AnnotatedString): TransformedText {
        val originalText = text.text
        if (originalText.isEmpty()) return TransformedText(text, OffsetMapping.Identity)

        val formattedText = formatIndianCurrency(originalText)

        val offsetMapping = object : OffsetMapping {
            override fun originalToTransformed(offset: Int): Int {
                if (offset <= 0) return 0
                if (offset >= originalText.length) return formattedText.length

                val lengthFromEnd = originalText.length - offset
                val commasTotal = getCommaCount(originalText.length)
                val commasAfter = getCommaCount(lengthFromEnd)
                val commasBefore = commasTotal - commasAfter
                return offset + commasBefore
            }

            override fun transformedToOriginal(offset: Int): Int {
                if (offset <= 0) return 0
                if (offset >= formattedText.length) return originalText.length

                var originalOffset = 0
                var transformedCount = 0
                for (i in 0 until formattedText.length) {
                    if (transformedCount == offset) break
                    if (formattedText[i] != ',') {
                        originalOffset++
                    }
                    transformedCount++
                }
                return originalOffset
            }
        }

        return TransformedText(AnnotatedString(formattedText), offsetMapping)
    }

    private fun formatIndianCurrency(text: String): String {
        if (text.length <= 3) return text
        val lastThree = text.substring(text.length - 3)
        var remaining = text.substring(0, text.length - 3)
        var formatted = lastThree
        while (remaining.length > 2) {
            val lastTwo = remaining.substring(remaining.length - 2)
            formatted = "$lastTwo,$formatted"
            remaining = remaining.substring(0, remaining.length - 2)
        }
        if (remaining.isNotEmpty()) {
            formatted = "$remaining,$formatted"
        }
        return formatted
    }

    private fun getCommaCount(length: Int): Int {
        if (length <= 3) return 0
        return 1 + (length - 3 - 1) / 2
    }
}
