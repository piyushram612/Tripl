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
import androidx.compose.ui.unit.sp
import com.piyushram612.tallytap.ui.theme.*
import kotlin.math.roundToInt
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

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
    
    val focusRequester = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current
    val darkTheme = isSystemInDarkTheme()

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
                    .padding(top = 72.dp, start = 16.dp, end = 16.dp)
                    .pointerInput(Unit) {
                        detectVerticalDragGestures(
                            onDragEnd = {
                                coroutineScope.launch {
                                    if (dragOffsetY.value < -150f) {
                                        onClose()
                                    } else {
                                        dragOffsetY.animateTo(0f, tween(300))
                                    }
                                }
                            },
                            onVerticalDrag = { change, dragAmount ->
                                change.consume()
                                coroutineScope.launch {
                                    val newOffset = dragOffsetY.value + dragAmount
                                    if (newOffset <= 0f) {
                                        dragOffsetY.snapTo(newOffset)
                                    }
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
                        shape = RoundedCornerShape(28.dp),
                        clip = false,
                        ambientColor = if (darkTheme) PrimaryGreen.copy(alpha = 0.2f) else Color.Black.copy(alpha = 0.4f),
                        spotColor = if (darkTheme) PrimaryGreen.copy(alpha = 0.4f) else Color.Black.copy(alpha = 0.5f)
                    ),
                shape = RoundedCornerShape(28.dp),
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
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    // Header Bar
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
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
                                )
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
                            onValueChange = { newVal ->
                                val cleanText = newVal.text.filter { it.isDigit() }
                                if (cleanText.isEmpty()) {
                                    amount = TextFieldValue("0", selection = TextRange(1))
                                } else {
                                    val formatted = if (cleanText.length > 1 && cleanText.startsWith("0")) {
                                        cleanText.substring(1)
                                    } else {
                                        cleanText
                                    }
                                    amount = TextFieldValue(formatted, selection = TextRange(formatted.length))
                                }
                            },
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
                            singleLine = true,
                            modifier = Modifier
                                .width(180.dp)
                                .focusRequester(focusRequester)
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

                    Spacer(modifier = Modifier.height(20.dp))

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
