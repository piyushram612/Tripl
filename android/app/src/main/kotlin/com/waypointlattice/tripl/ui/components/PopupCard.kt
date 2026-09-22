package com.waypointlattice.tripl.ui.components

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
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.Spring
import androidx.compose.ui.graphics.TransformOrigin
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
import com.waypointlattice.tripl.ui.components.core.ScrollableCategoryCapsule
import com.waypointlattice.tripl.ui.components.core.SectionHeader
import com.waypointlattice.tripl.ui.components.core.CustomInputField
import com.waypointlattice.tripl.ui.theme.LocalTriplColors
import com.waypointlattice.tripl.utils.TransactionManager
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
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

fun Modifier.outerGlow(
    color: Color,
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
    val theme = LocalTriplColors.current
    
    val greenPrimary = theme.primaryAccent
    val cardBgDark = theme.cardBg
    val borderDark = theme.cardBorder
    val textPrimary = theme.textPrimary
    val textMuted = theme.textMuted
    val inactivePill = if (theme.isLight) borderDark.copy(alpha = 0.4f) else borderDark.copy(alpha = 0.3f)
    val ctaTextColor = if (theme.isLight) Color.White else theme.bgBase

    val currency = remember(context) { TransactionManager.getGlobalCurrency(context) }
    val categories = remember(context) { TransactionManager.getCustomCategories(context) }
    val sources = remember(context) { TransactionManager.getCustomSources(context) }
    val categoryColors = remember(context) { TransactionManager.getCategoryColors(context) }
    val sourceColors = remember(context) { TransactionManager.getSourceColors(context) }
    val categoryVisibilities = remember(context) { TransactionManager.getCategoryVisibilities(context) }

    var visible by remember { mutableStateOf(false) }
    var isExpanded by remember { mutableStateOf(false) }
    var showActionDialog by remember { mutableStateOf(false) }
    val scale = remember { Animatable(0.85f) }

    // Input States
    var title by remember { mutableStateOf("") }
    var amount by remember { mutableStateOf(TextFieldValue("", selection = TextRange(0))) }
    var selectedCategory by remember { mutableStateOf<String?>(null) }
    var selectedSource by remember { mutableStateOf<String?>(null) }
    
    var transactionType by remember { mutableStateOf("EXPENSE") }
    var dateText by remember { mutableStateOf(SimpleDateFormat("dd MMM yyyy", Locale.US).format(Date())) }
    var timeText by remember { mutableStateOf(SimpleDateFormat("hh:mm a", Locale.US).format(Date())) }
    var paidTo by remember { mutableStateOf("") }
    var finishLater by remember { mutableStateOf(false) }
    var reminderDate by remember { mutableStateOf(SimpleDateFormat("dd.MM.yyyy", Locale.US).format(Date())) }
    var reminderTime by remember { mutableStateOf("09:00") }
    
    val isIncome = transactionType == "INCOME"

    val filteredCategories = remember(isIncome, categories, categoryVisibilities) {
        categories.filter { cat ->
            if (cat.equals("income", ignoreCase = true)) return@filter false
            val vis = categoryVisibilities[cat] ?: "expense"
            if (isIncome) {
                vis == "income" || vis == "both"
            } else {
                vis == "expense" || vis == "both"
            }
        }
    }

    LaunchedEffect(filteredCategories) {
        if (selectedCategory != null && !filteredCategories.contains(selectedCategory)) {
            selectedCategory = null
        }
    }

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
            .statusBarsPadding()
            .imePadding()
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { 
                if (showActionDialog) showActionDialog = false else onClose()
            },
        contentAlignment = Alignment.TopCenter
    ) {
        AnimatedVisibility(
            visible = visible,
            enter = fadeIn(animationSpec = tween(250)) + scaleIn(initialScale = 0.85f, animationSpec = tween(280))
        ) {
            Card(
                modifier = Modifier
                    .padding(top = 16.dp, start = 16.dp, end = 16.dp)
                    .widthIn(max = 560.dp)
                    .then(if (isExpanded) Modifier.fillMaxWidth() else Modifier.fillMaxWidth(0.96f))
                    .wrapContentHeight()
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
                    containerColor = cardBgDark
                ),
                border = BorderStroke(
                    width = 1.5.dp,
                    color = borderDark
                )
            ) {
                Box(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .verticalScroll(rememberScrollState())
                            .padding(top = 36.dp, bottom = 48.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        // 1. TITLE INPUT FIELD
                        BasicTextField(
                            value = title,
                            onValueChange = { title = it },
                            textStyle = TextStyle(
                                fontSize = 18.sp,
                                fontWeight = FontWeight.Bold,
                                color = textPrimary,
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
                                                color = textMuted,
                                                textAlign = TextAlign.Center
                                            )
                                        )
                                    }
                                    innerTextField()
                                }
                            },
                            keyboardOptions = KeyboardOptions(
                                capitalization = KeyboardCapitalization.Sentences,
                                imeAction = ImeAction.Next
                            ),
                            singleLine = true,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 24.dp)
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
                                color = textPrimary,
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
                                                color = textMuted,
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
                                                    color = textPrimary
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
                                .padding(horizontal = 24.dp)
                                .focusRequester(focusRequester)
                        )

                        Spacer(modifier = Modifier.height(24.dp))

                        // 3. CATEGORY HEADER & CAPSULES ROW
                        SectionHeader("CATEGORY", modifier = Modifier.padding(horizontal = 24.dp))
                        Box(modifier = Modifier.fillMaxWidth().height(66.dp)) {
                            Row(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .horizontalScroll(rememberScrollState()),
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Spacer(modifier = Modifier.width(14.dp))
                                filteredCategories.forEach { cat ->
                                    ScrollableCategoryCapsule(
                                        label = cat,
                                        isSelected = (selectedCategory == cat),
                                        onClick = { selectedCategory = cat },
                                        accentColor = categoryColors[cat]?.let { Color(it) } ?: greenPrimary
                                    )
                                }
                                Spacer(modifier = Modifier.width(14.dp))
                            }
                            
                            // Left Fading Edge Overlay
                            Box(
                                modifier = Modifier
                                    .align(Alignment.CenterStart)
                                    .fillMaxHeight()
                                    .width(24.dp)
                                    .background(
                                        brush = androidx.compose.ui.graphics.Brush.horizontalGradient(
                                            colors = listOf(cardBgDark, Color.Transparent)
                                        )
                                    )
                                )
                            
                            // Right Fading Edge Overlay
                            Box(
                                modifier = Modifier
                                    .align(Alignment.CenterEnd)
                                    .fillMaxHeight()
                                    .width(24.dp)
                                    .background(
                                        brush = androidx.compose.ui.graphics.Brush.horizontalGradient(
                                            colors = listOf(Color.Transparent, cardBgDark)
                                        )
                                    )
                            )
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        // 4. SOURCE HEADER & CAPSULES ROW
                        SectionHeader("SOURCE", modifier = Modifier.padding(horizontal = 24.dp))
                        Box(modifier = Modifier.fillMaxWidth().height(66.dp)) {
                            Row(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .horizontalScroll(rememberScrollState()),
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Spacer(modifier = Modifier.width(14.dp))
                                sources.forEach { src ->
                                    ScrollableCategoryCapsule(
                                        label = src,
                                        isSelected = (selectedSource == src),
                                        onClick = { selectedSource = src },
                                        accentColor = sourceColors[src]?.let { Color(it) } ?: greenPrimary
                                    )
                                }
                                Spacer(modifier = Modifier.width(14.dp))
                            }
                            
                            // Left Fading Edge Overlay
                            Box(
                                modifier = Modifier
                                    .align(Alignment.CenterStart)
                                    .fillMaxHeight()
                                    .width(24.dp)
                                    .background(
                                        brush = androidx.compose.ui.graphics.Brush.horizontalGradient(
                                            colors = listOf(cardBgDark, Color.Transparent)
                                        )
                                    )
                            )
                            
                            // Right Fading Edge Overlay
                            Box(
                                modifier = Modifier
                                    .align(Alignment.CenterEnd)
                                    .fillMaxHeight()
                                    .width(24.dp)
                                    .background(
                                        brush = androidx.compose.ui.graphics.Brush.horizontalGradient(
                                            colors = listOf(Color.Transparent, cardBgDark)
                                        )
                                    )
                            )
                        }

                        // EXPANDED CONTENT
                        AnimatedVisibility(visible = isExpanded) {
                            Column(modifier = Modifier.fillMaxWidth()) {
                                Spacer(modifier = Modifier.height(16.dp))
                                
                                // TYPE Segmented Button
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 24.dp)
                                        .height(48.dp)
                                        .background(inactivePill, RoundedCornerShape(24.dp))
                                        .border(1.dp, borderDark, RoundedCornerShape(24.dp))
                                        .padding(4.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    listOf("EXPENSE", "INCOME").forEach { type ->
                                        val isSelected = transactionType == type
                                        val isExpense = type == "EXPENSE"
                                        
                                        Box(
                                            modifier = Modifier
                                                .weight(1f)
                                                .fillMaxHeight()
                                                .clip(RoundedCornerShape(20.dp))
                                                .background(
                                                    if (isSelected) {
                                                        if (isExpense) greenPrimary else Color(0xFF10B981)
                                                    } else {
                                                        Color.Transparent
                                                    }
                                                )
                                                .clickable(
                                                    interactionSource = remember { MutableInteractionSource() },
                                                    indication = null
                                                ) { 
                                                    transactionType = type 
                                                },
                                            contentAlignment = Alignment.Center
                                        ) {
                                            Text(
                                                text = type,
                                                style = TextStyle(
                                                    fontSize = 13.sp,
                                                    fontWeight = FontWeight.W900,
                                                    letterSpacing = 0.5.sp,
                                                    color = if (isSelected) ctaTextColor else textMuted
                                                )
                                            )
                                        }
                                    }
                                }

                                Spacer(modifier = Modifier.height(16.dp))

                                // DATE & TIME
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 24.dp),
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
                                Box(modifier = Modifier.padding(horizontal = 24.dp)) {
                                    CustomInputField(
                                        label = if (isIncome) "PAID BY (OPTIONAL)" else "PAID TO (OPTIONAL)",
                                        value = paidTo,
                                        onValueChange = { paidTo = it },
                                        icon = Icons.Default.Storefront,
                                        placeholder = if (isIncome) "e.g. Employer, Client..." else "e.g. Landlord, Store Name..."
                                    )
                                }

                                Spacer(modifier = Modifier.height(16.dp))

                                // FINISH LATER CHECKBOX
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 24.dp)
                                        .clickable(
                                            interactionSource = remember { MutableInteractionSource() },
                                            indication = null
                                        ) { finishLater = !finishLater },
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(24.dp)
                                            .background(if (finishLater) greenPrimary else inactivePill, RoundedCornerShape(6.dp))
                                            .border(1.dp, if (finishLater) greenPrimary else Color.Transparent, RoundedCornerShape(6.dp)),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        if (finishLater) {
                                            Icon(Icons.Outlined.Check, contentDescription = null, tint = ctaTextColor, modifier = Modifier.size(16.dp))
                                        }
                                    }
                                    Spacer(modifier = Modifier.width(14.dp))
                                    Text(
                                        text = if (isIncome) "Verify Receipt" else "Finish later",
                                        style = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.W600, color = textPrimary)
                                    )
                                }

                                AnimatedVisibility(visible = finishLater) {
                                    Column {
                                        Spacer(modifier = Modifier.height(16.dp))
                                        Row(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .padding(horizontal = 24.dp),
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
                                .padding(horizontal = 24.dp)
                                .height(56.dp)
                                .outerGlow(color = greenPrimary, radius = 24.dp, alpha = 0.45f, cornerRadius = 100.dp)
                                .background(greenPrimary, RoundedCornerShape(100.dp))
                                .clickable {
                                    if (amount.text.isBlank()) {
                                        Toast.makeText(context, "Please enter an amount", Toast.LENGTH_SHORT).show()
                                        return@clickable
                                    }

                                    val cat = selectedCategory
                                    val src = selectedSource
                                    if (cat == null || src == null) {
                                        Toast.makeText(context, "Please select a category and payment source", Toast.LENGTH_SHORT).show()
                                        return@clickable
                                    }

                                    val isoReminderDate = if (finishLater) {
                                        try {
                                            val sdfInput = SimpleDateFormat("dd.MM.yyyy hh:mm a", Locale.US)
                                            val parsedDate = sdfInput.parse("$reminderDate $reminderTime")
                                            val sdfOutput = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                                                timeZone = TimeZone.getTimeZone("UTC")
                                            }
                                            if (parsedDate != null) sdfOutput.format(parsedDate) else null
                                        } catch (e: Exception) { null }
                                    } else null

                                    val isoDate = try {
                                        val sdfInput = SimpleDateFormat("dd MMM yyyy hh:mm a", Locale.US)
                                        val parsedDate = sdfInput.parse("$dateText $timeText")
                                        val sdfOutput = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)
                                        if (parsedDate != null) sdfOutput.format(parsedDate) else null
                                    } catch (e: Exception) {
                                        null
                                    }

                                    TransactionManager.saveTransactionToPrefs(
                                        context = context,
                                        titleText = if (title.isNotBlank()) title else (if (isIncome) "Quick Income" else "Quick Expense"),
                                        amountText = amount.text,
                                        category = cat,
                                        source = src,
                                        paidTo = paidTo,
                                        needsVerification = finishLater,
                                        reminderDate = isoReminderDate,
                                        dateString = isoDate,
                                        isIncome = isIncome
                                    )
                                    Toast.makeText(context, "Logged: $currency${amount.text} to $cat", Toast.LENGTH_SHORT).show()
                                    onClose()
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = if (isIncome) "LOG INCOME" else "LOG EXPENSE",
                                style = TextStyle(
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.W900,
                                    letterSpacing = 0.5.sp,
                                    color = ctaTextColor
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
                                .background(textMuted.copy(alpha = 0.4f), CircleShape)
                        )
                    }

                    // OPEN IN APP BUTTON (ICON ONLY)
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .padding(top = 16.dp, end = 16.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(borderDark)
                            .clickable {
                                showActionDialog = true
                            }
                            .padding(10.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.OpenInNew,
                            contentDescription = "Open in app options",
                            tint = greenPrimary,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }
        }

        // ACTION SELECTION DIALOG OVERLAY (Originating from top-right button)
        AnimatedVisibility(
            visible = showActionDialog,
            enter = fadeIn(animationSpec = tween(200)) + scaleIn(
                initialScale = 0.1f,
                transformOrigin = TransformOrigin(0.88f, 0.08f),
                animationSpec = spring(stiffness = Spring.StiffnessLow, dampingRatio = Spring.DampingRatioMediumBouncy)
            ),
            exit = fadeOut(animationSpec = tween(150)) + scaleOut(
                targetScale = 0.1f,
                transformOrigin = TransformOrigin(0.88f, 0.08f),
                animationSpec = tween(180)
            ),
            modifier = Modifier
                .padding(top = 64.dp, start = 20.dp, end = 20.dp)
                .fillMaxWidth(0.94f)
        ) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .outerGlow(color = greenPrimary, radius = 32.dp, alpha = 0.55f, cornerRadius = 28.dp)
                    .shadow(
                        elevation = 28.dp,
                        shape = RoundedCornerShape(28.dp),
                        clip = false,
                        ambientColor = greenPrimary.copy(alpha = 0.3f),
                        spotColor = greenPrimary.copy(alpha = 0.4f)
                    )
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) { /* catch clicks inside card */ },
                shape = RoundedCornerShape(28.dp),
                colors = CardDefaults.cardColors(containerColor = cardBgDark),
                border = BorderStroke(1.5.dp, greenPrimary.copy(alpha = 0.6f))
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(20.dp)
                ) {
                    // Dialog Header
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = "Create Options",
                                style = TextStyle(
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = textPrimary
                                )
                            )
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = "Select transaction type to open in app",
                                style = TextStyle(
                                    fontSize = 12.sp,
                                    color = textMuted
                                )
                            )
                        }
                        IconButton(
                            onClick = { showActionDialog = false },
                            modifier = Modifier
                                .size(32.dp)
                                .background(borderDark, CircleShape)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Close,
                                contentDescription = "Close dialog",
                                tint = textMuted,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    // Option 1: Create New Transaction
                    ActionDialogOptionItem(
                        icon = Icons.Default.AddCircleOutline,
                        title = "Create New Transaction",
                        description = "Log a single expense or income immediately",
                        greenPrimary = greenPrimary,
                        borderDark = borderDark,
                        textPrimary = textPrimary,
                        textMuted = textMuted,
                        onClick = {
                            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                                flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP
                                putExtra("navigate", "create_transaction")
                            }
                            context.startActivity(launchIntent)
                            showActionDialog = false
                            onClose()
                        }
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    // Option 2: Create Recurring Transaction
                    ActionDialogOptionItem(
                        icon = Icons.Default.Autorenew,
                        title = "Create Recurring Transaction",
                        description = "Schedule repeating bills, income, or subscriptions",
                        greenPrimary = greenPrimary,
                        borderDark = borderDark,
                        textPrimary = textPrimary,
                        textMuted = textMuted,
                        onClick = {
                            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                                flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP
                                putExtra("navigate", "create_recurring")
                            }
                            context.startActivity(launchIntent)
                            showActionDialog = false
                            onClose()
                        }
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    // Option 3: Create Group Transaction
                    ActionDialogOptionItem(
                        icon = Icons.Default.Groups,
                        title = "Create Group Transaction",
                        description = "Split a bill with friends and track shared shares",
                        greenPrimary = greenPrimary,
                        borderDark = borderDark,
                        textPrimary = textPrimary,
                        textMuted = textMuted,
                        onClick = {
                            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                                flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP
                                putExtra("navigate", "expense_splitter")
                            }
                            context.startActivity(launchIntent)
                            showActionDialog = false
                            onClose()
                        }
                    )
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
                }) { Text("OK", color = greenPrimary) }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text("Cancel", color = textPrimary) }
            },
            colors = DatePickerDefaults.colors(containerColor = cardBgDark)
        ) {
            DatePicker(state = datePickerState, colors = DatePickerDefaults.colors(
                titleContentColor = greenPrimary,
                headlineContentColor = textPrimary,
                weekdayContentColor = textMuted,
                dayContentColor = textPrimary,
                selectedDayContainerColor = greenPrimary,
                selectedDayContentColor = ctaTextColor,
                todayContentColor = greenPrimary,
                todayDateBorderColor = greenPrimary
            ))
        }
    }
    
    if (showTimePicker) {
        val timePickerState = rememberTimePickerState()
        DatePickerDialog(
            onDismissRequest = { showTimePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    val cal = Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, timePickerState.hour)
                        set(Calendar.MINUTE, timePickerState.minute)
                    }
                    timeText = SimpleDateFormat("hh:mm a", Locale.US).format(cal.time)
                    showTimePicker = false
                }) { Text("OK", color = greenPrimary) }
            },
            dismissButton = {
                TextButton(onClick = { showTimePicker = false }) { Text("Cancel", color = textPrimary) }
            },
            colors = DatePickerDefaults.colors(containerColor = cardBgDark)
        ) {
            TimePicker(
                state = timePickerState,
                modifier = Modifier.padding(24.dp).align(Alignment.CenterHorizontally),
                colors = TimePickerDefaults.colors(
                    clockDialColor = inactivePill,
                    selectorColor = greenPrimary,
                    clockDialSelectedContentColor = ctaTextColor,
                    clockDialUnselectedContentColor = textPrimary,
                    timeSelectorSelectedContainerColor = greenPrimary.copy(alpha = 0.2f),
                    timeSelectorSelectedContentColor = greenPrimary,
                    timeSelectorUnselectedContainerColor = inactivePill,
                    timeSelectorUnselectedContentColor = textPrimary
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
                }) { Text("OK", color = greenPrimary) }
            },
            dismissButton = {
                TextButton(onClick = { showReminderDatePicker = false }) { Text("Cancel", color = textPrimary) }
            },
            colors = DatePickerDefaults.colors(containerColor = cardBgDark)
        ) {
            DatePicker(state = datePickerState, colors = DatePickerDefaults.colors(
                titleContentColor = greenPrimary,
                headlineContentColor = textPrimary,
                weekdayContentColor = textMuted,
                dayContentColor = textPrimary,
                selectedDayContainerColor = greenPrimary,
                selectedDayContentColor = ctaTextColor,
                todayContentColor = greenPrimary,
                todayDateBorderColor = greenPrimary
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
                }) { Text("OK", color = greenPrimary) }
            },
            dismissButton = {
                TextButton(onClick = { showReminderTimePicker = false }) { Text("Cancel", color = textPrimary) }
            },
            colors = DatePickerDefaults.colors(containerColor = cardBgDark)
        ) {
            TimePicker(
                state = timePickerState,
                modifier = Modifier.padding(24.dp).align(Alignment.CenterHorizontally),
                colors = TimePickerDefaults.colors(
                    clockDialColor = inactivePill,
                    selectorColor = greenPrimary,
                    clockDialSelectedContentColor = ctaTextColor,
                    clockDialUnselectedContentColor = textPrimary,
                    timeSelectorSelectedContainerColor = greenPrimary.copy(alpha = 0.2f),
                    timeSelectorSelectedContentColor = greenPrimary,
                    timeSelectorUnselectedContainerColor = inactivePill,
                    timeSelectorUnselectedContentColor = textPrimary
                )
            )
        }
    }
}

@Composable
private fun ActionDialogOptionItem(
    icon: ImageVector,
    title: String,
    description: String,
    greenPrimary: Color,
    borderDark: Color,
    textPrimary: Color,
    textMuted: Color,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(borderDark.copy(alpha = 0.4f))
            .border(1.dp, greenPrimary.copy(alpha = 0.25f), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(42.dp)
                .background(greenPrimary.copy(alpha = 0.15f), CircleShape)
                .border(1.dp, greenPrimary.copy(alpha = 0.35f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = title,
                tint = greenPrimary,
                modifier = Modifier.size(22.dp)
            )
        }
        Spacer(modifier = Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = TextStyle(
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = textPrimary
                )
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = description,
                style = TextStyle(
                    fontSize = 11.sp,
                    color = textMuted,
                    lineHeight = 15.sp
                )
            )
        }
        Icon(
            imageVector = Icons.Default.ChevronRight,
            contentDescription = null,
            tint = greenPrimary.copy(alpha = 0.7f),
            modifier = Modifier.size(18.dp)
        )
    }
}

