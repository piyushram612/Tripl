package com.piyushram612.tallytap.ui.components.core

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.piyushram612.tallytap.ui.components.outerGlow

@Composable
fun ScrollableCategoryCapsule(
    label: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    accentColor: Color = GreenPrimary
) {
    Box(
        modifier = Modifier
            .height(42.dp)
            .then(if (isSelected) Modifier.outerGlow(color = accentColor, radius = 12.dp, alpha = 0.35f, cornerRadius = 100.dp) else Modifier)
            .clip(RoundedCornerShape(100.dp))
            .background(if (isSelected) accentColor.copy(alpha = 0.15f) else InactivePill)
            .border(
                width = 1.0.dp,
                color = if (isSelected) accentColor else Color.Transparent,
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
                color = if (isSelected) accentColor else Color.White.copy(alpha = 0.8f)
            ),
            maxLines = 1
        )
    }
}
