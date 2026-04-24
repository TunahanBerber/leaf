import { Dimensions } from 'react-native';

const { width, height } = Dimensions.get('window');

export const Theme = {
    colors: {
        // Brand Colors
        primaryLight: 'rgba(47, 125, 92, 1)',
        primaryDark: 'rgba(73, 192, 141, 1)',

        // Gradient Background
        bgTopLight: 'rgba(250, 251, 252, 1)',
        bgBottomLight: 'rgba(154, 191, 241, 1)',
        bgTopDark: 'rgba(0, 0, 0, 1)',
        bgBottomDark: 'rgba(3, 11, 35, 1)',

        // Surface Colors (Glass layer)
        surfacePrimaryLight: 'rgba(255, 255, 255, 0.78)',
        surfaceSecondaryLight: 'rgba(255, 255, 255, 0.64)',
        surfacePrimaryDark: 'rgba(24, 25, 31, 0.72)',
        surfaceSecondaryDark: 'rgba(24, 25, 31, 0.56)',

        // Text Colors
        textPrimaryLight: 'rgba(12, 14, 18, 0.92)',
        textSecondaryLight: 'rgba(12, 14, 18, 0.70)',
        textTertiaryLight: 'rgba(12, 14, 18, 0.52)',

        textPrimaryDark: 'rgba(245, 246, 248, 0.92)',
        textSecondaryDark: 'rgba(245, 246, 248, 0.70)',
        textTertiaryDark: 'rgba(245, 246, 248, 0.52)',

        // Border Colors
        borderSubtleLight: 'rgba(15, 18, 22, 0.06)',
        borderPrimaryLight: 'rgba(15, 18, 22, 0.10)',

        borderSubtleDark: 'rgba(245, 246, 248, 0.08)',
        borderPrimaryDark: 'rgba(245, 246, 248, 0.14)',
    },

    spacing: {
        xxs: 4,
        xs: 8,
        sm: 12,
        md: 16,
        lg: 20,
        xl: 24,
        xxl: 32,
        xxxl: 40,
    },

    radius: {
        small: 10,
        medium: 14,
        large: 18,
        xlarge: 24,
    },

    window: {
        width,
        height,
    }
};

export const getTheme = (isDark: boolean) => {
    return {
        primary: isDark ? Theme.colors.primaryDark : Theme.colors.primaryLight,
        bgTop: isDark ? Theme.colors.bgTopDark : Theme.colors.bgTopLight,
        bgBottom: isDark ? Theme.colors.bgBottomDark : Theme.colors.bgBottomLight,
        surfacePrimary: isDark ? Theme.colors.surfacePrimaryDark : Theme.colors.surfacePrimaryLight,
        surfaceSecondary: isDark ? Theme.colors.surfaceSecondaryDark : Theme.colors.surfaceSecondaryLight,
        textPrimary: isDark ? Theme.colors.textPrimaryDark : Theme.colors.textPrimaryLight,
        textSecondary: isDark ? Theme.colors.textSecondaryDark : Theme.colors.textSecondaryLight,
        textTertiary: isDark ? Theme.colors.textTertiaryDark : Theme.colors.textTertiaryLight,
        borderSubtle: isDark ? Theme.colors.borderSubtleDark : Theme.colors.borderSubtleLight,
        borderPrimary: isDark ? Theme.colors.borderPrimaryDark : Theme.colors.borderPrimaryLight,
    };
};
