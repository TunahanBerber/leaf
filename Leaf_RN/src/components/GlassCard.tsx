import React from 'react';
import { View, StyleSheet, ViewStyle } from 'react-native';
import { BlurView } from 'expo-blur';
import { Theme, getTheme } from './theme';

interface GlassCardProps {
    children: React.ReactNode;
    style?: ViewStyle;
    isDark?: boolean;
}

export const GlassCard: React.FC<GlassCardProps> = ({ children, style, isDark = false }) => {
    const theme = getTheme(isDark);

    return (
        <View style={[styles.container, style]}>
            {/* Shadow layer underneath */}
            <View style={styles.shadowLayer} />

            {/* Blur Layer */}
            <BlurView
                intensity={80}
                tint={isDark ? "dark" : "light"}
                style={StyleSheet.absoluteFillObject}
            />

            {/* Surface Overlay */}
            <View
                style={[
                    styles.overlay,
                    {
                        backgroundColor: theme.surfacePrimary,
                        borderColor: theme.borderSubtle
                    }
                ]}
            />

            {/* Content */}
            <View style={styles.content}>
                {children}
            </View>
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        borderRadius: Theme.radius.large,
        overflow: 'hidden', // keep the blur and overlay inside the border radius
        // the shadow in react native needs to be applied differently since overflow: 'hidden' clips shadows
    },
    shadowLayer: {
        ...StyleSheet.absoluteFillObject,
        borderRadius: Theme.radius.large,
        backgroundColor: 'transparent',
        boxShadow: '0px 8px 16px rgba(0, 0, 0, 0.06)' as any,
        elevation: 4,
    },
    overlay: {
        ...StyleSheet.absoluteFillObject,
        borderRadius: Theme.radius.large,
        borderWidth: 0.5,
    },
    content: {
        position: 'relative',
        zIndex: 1,
    } // to ensure content sits on top
});

// Since overflow: hidden clips shadow in RN, here's a wrapper if shadow is needed:
export const ShadowedGlassCard: React.FC<GlassCardProps> = (props) => {
    return (
        <View style={shadowWrapperStyle}>
            <GlassCard {...props} />
        </View>
    );
};

// ... we add shadow wrapper styles ...
const shadowWrapperStyle = {
    boxShadow: '0px 8px 16px rgba(0, 0, 0, 0.06)',
    elevation: 4,
} as any;
