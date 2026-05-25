package com.piyushram612.tallytap.ui.components.core

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.piyushram612.tallytap.ui.components.outerGlow

val GreenPrimary = Color(0xFF10B981)
val InactivePill = Color(0xFF131D1A)

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
                            fontWeight = FontWeight.W600,
                            color = if (value.isNotEmpty()) Color.White else Color.White.copy(alpha = 0.4f)
                        )
                    )
                }
            }
        }
    }
}
