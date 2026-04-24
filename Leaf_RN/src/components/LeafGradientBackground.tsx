import React from 'react';
import { StyleSheet } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { getTheme } from './theme';

interface LeafGradientBackgroundProps {
    isDark?: boolean;
}

export const LeafGradientBackground: React.FC<LeafGradientBackgroundProps> = ({ isDark = false }) => {
    const theme = getTheme(isDark);

    return (
        <LinearGradient
            colors={[theme.bgTop, theme.bgBottom]}
            start={{ x: 0.5, y: 0 }}
            end={{ x: 0.5, y: 1 }}
            style={StyleSheet.absoluteFillObject}
        />
    );
};
