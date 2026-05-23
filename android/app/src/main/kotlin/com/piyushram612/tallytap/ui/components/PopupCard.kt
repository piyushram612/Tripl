package com.piyushram612.tallytap.ui.components

import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Fastfood
import androidx.compose.material.icons.rounded.LocalGasStation
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
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.piyushram612.tallytap.ui.theme.*
import kotlinx.coroutines.delay

@Composable
fun PopupCard(
    onClose: () -> Unit
) {
    val context = LocalContext.current
    var visible by remember { mutableStateOf(false) }
    
    // Scale animation state
    val scale = remember { Animatable(0.85f) }
    
    // Input Fields States
    var amount by remember { mutableStateOf(TextFieldValue("0", selection = TextRange(1))) }
    var note by remember { mutableStateOf("") }
    var selectedCategory by remember { mutableStateOf("Food") }
    
    val focusRequester = remember { FocusRequester() }
    val focusManager = LocalFocusManager.current
    val darkTheme = isSystemInDarkTheme()

    // Slide/Fade-in triggering
    LaunchedEffect(Unit) {
        visible = true
        scale.animateTo(
            targetValue = 1.0f,
            animationSpec = tween(durationMillis = 280)
        )
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
        contentAlignment = Alignment.Center
    ) {
        AnimatedVisibility(
            visible = visible,
            enter = fadeIn(animationSpec = tween(250)) + scaleIn(initialScale = 0.85f, animationSpec = tween(280))
        ) {
            Card(
                modifier = Modifier
                    .width(320.dp)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) { /* Catch taps inside card to prevent dismissal */ }
                    .shadow(
                        elevation = 24.dp,
                        shape = RoundedCornerShape(28.dp),
                        clip = false,
                        ambientColor = Color.Black.copy(alpha = 0.4f),
                        spotColor = Color.Black.copy(alpha = 0.5f)
                    ),
                shape = RoundedCornerShape(28.dp),
                colors = CardDefaults.cardColors(
                    containerColor = if (darkTheme) CardBgDark else CardBgLight
                ),
                border = BorderStroke(
                    width = 1.dp,
                    brush = Brush.linearGradient(
                        colors = if (darkTheme) {
                            listOf(BorderDark, Color(0xFF3B3B4F))
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
                                    .background(PrimaryViolet)
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
                        
                        // Close Action
                        Box(
                            modifier = Modifier
                                .size(28.dp)
                                .clip(CircleShape)
                                .background(if (darkTheme) Color(0xFF232333) else Color(0xFFF3F4F6))
                                .clickable { onClose() },
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Rounded.Close,
                                contentDescription = "Close Trigger",
                                modifier = Modifier.size(16.dp),
                                tint = if (darkTheme) Color.White.copy(alpha = 0.6f) else Color.Black.copy(alpha = 0.6f)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(20.dp))

                    // Autofocused Currency Input (Frictionless logging)
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.Center,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = "₹",
                            style = TextStyle(
                                fontSize = 42.sp,
                                fontWeight = FontWeight.W900,
                                color = PrimaryViolet
                            )
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        
                        BasicTextField(
                            value = amount,
                            onValueChange = { newVal ->
                                // Clean value processing
                                val cleanText = newVal.text.filter { it.isDigit() }
                                if (cleanText.isEmpty()) {
                                    amount = TextFieldValue("0", selection = TextRange(1))
                                } else {
                                    // Remove leading zero if digit is typed
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

                    // Minimal Mini Quick Category Selector
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        CategoryChip("Food", Icons.Rounded.Fastfood, selectedCategory == "Food", darkTheme) {
                            selectedCategory = "Food"
                        }
                        CategoryChip("Fuel", Icons.Rounded.LocalGasStation, selectedCategory == "Fuel", darkTheme) {
                            selectedCategory = "Fuel"
                        }
                        CategoryChip("Shop", Icons.Rounded.ShoppingBag, selectedCategory == "Shop", darkTheme) {
                            selectedCategory = "Shop"
                        }
                        CategoryChip("Bills", Icons.Rounded.Receipt, selectedCategory == "Bills", darkTheme) {
                            selectedCategory = "Bills"
                        }
                    }

                    Spacer(modifier = Modifier.height(20.dp))

                    // Optional short note input field
                    OutlinedTextField(
                        value = note,
                        onValueChange = { note = it },
                        placeholder = { 
                            Text(
                                "Add quick note (optional)...",
                                style = TextStyle(fontSize = 13.sp, color = TextGray)
                            )
                        },
                        textStyle = TextStyle(fontSize = 13.sp, color = if (darkTheme) Color.White else TextLight),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = PrimaryViolet,
                            unfocusedBorderColor = if (darkTheme) BorderDark else BorderLight,
                            focusedContainerColor = if (darkTheme) Color(0xFF1D1D2B) else Color(0xFFF9FAFB),
                            unfocusedContainerColor = if (darkTheme) Color(0xFF1D1D2B) else Color(0xFFF9FAFB)
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

                    Spacer(modifier = Modifier.height(24.dp))

                    // Frictionless trigger logging CTA button
                    Button(
                        onClick = {
                            Toast.makeText(context, "Log Successful: ₹${amount.text} ($selectedCategory)", Toast.LENGTH_SHORT).show()
                            onClose()
                        },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = PrimaryViolet,
                            contentColor = Color.White
                        ),
                        shape = RoundedCornerShape(16.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(50.dp),
                        elevation = ButtonDefaults.buttonElevation(defaultElevation = 2.dp)
                    ) {
                        Text(
                            text = "Tap to Log",
                            style = TextStyle(
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Bold,
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
fun RowScope.CategoryChip(
    label: String,
    icon: ImageVector,
    isSelected: Boolean,
    darkTheme: Boolean,
    onClick: () -> Unit
) {
    val bgColor = when {
        isSelected -> PrimaryViolet
        darkTheme -> Color(0xFF1E1E2D)
        else -> Color(0xFFF3F4F6)
    }
    
    val contentColor = when {
        isSelected -> Color.White
        darkTheme -> Color.White.copy(alpha = 0.7f)
        else -> Color.Black.copy(alpha = 0.6f)
    }

    Box(
        modifier = Modifier
            .weight(1f)
            .padding(horizontal = 4.dp)
            .height(38.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(bgColor)
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = label,
                modifier = Modifier.size(15.dp),
                tint = contentColor
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = label,
                style = TextStyle(
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Bold,
                    color = contentColor
                )
            )
        }
    }
}
