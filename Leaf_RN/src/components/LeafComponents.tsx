import React, { useState, useRef } from 'react';
import { View, Text, TextInput, StyleSheet, Animated, Pressable, KeyboardTypeOptions, TextInputProps } from 'react-native';
import { Theme, getTheme } from './theme';

interface LeafTextFieldProps extends TextInputProps {
    title: string;
    text: string;
    onChangeText: (text: string) => void;
    placeholder?: string;
    keyboardType?: KeyboardTypeOptions;
    isDark?: boolean;
}

export const LeafTextField: React.FC<LeafTextFieldProps> = ({
    title,
    text,
    onChangeText,
    placeholder = '',
    keyboardType = 'default',
    isDark = false,
    ...props
}) => {
    const theme = getTheme(isDark);
    const [isFocused, setIsFocused] = useState(false);

    return (
        <View style={styles.container}>
            <Text style={[styles.title, { color: theme.textSecondary }]}>{title}</Text>

            <View style={[
                styles.inputContainer,
                {
                    backgroundColor: theme.surfacePrimary,
                    borderColor: isFocused ? theme.primary : theme.borderSubtle,
                }
            ]}>
                <TextInput
                    style={[styles.input, { color: theme.textPrimary }]}
                    value={text}
                    onChangeText={onChangeText}
                    placeholder={placeholder}
                    placeholderTextColor={theme.textTertiary}
                    keyboardType={keyboardType}
                    onFocus={() => setIsFocused(true)}
                    onBlur={() => setIsFocused(false)}
                    {...props}
                />
            </View>
        </View>
    );
};

// Pressable Scale Component for Buttons mapping the native SwiftUI behavior
export const PressableScale: React.FC<React.PropsWithChildren<{
    onPress?: () => void;
    style?: any;
    disabled?: boolean;
}>> = ({ children, onPress, style, disabled }) => {
    const scale = useRef(new Animated.Value(1)).current;

    const animateIn = () => {
        Animated.spring(scale, {
            toValue: 0.96,
            useNativeDriver: true,
            bounciness: 0,
            speed: 12,
        }).start();
    };

    const animateOut = () => {
        Animated.spring(scale, {
            toValue: 1,
            useNativeDriver: true,
            bounciness: 0,
            speed: 12,
        }).start();
    };

    return (
        <Pressable
            onPressIn={animateIn}
            onPressOut={animateOut}
            onPress={onPress}
            disabled={disabled}
        >
            <Animated.View style={[style, { transform: [{ scale }] }]}>
                {children}
            </Animated.View>
        </Pressable>
    );
};

const styles = StyleSheet.create({
    container: {
        marginBottom: Theme.spacing.md,
    },
    title: {
        fontSize: 13,
        fontWeight: '500',
        marginBottom: Theme.spacing.xs,
    },
    inputContainer: {
        borderRadius: Theme.radius.medium,
        borderWidth: 0.5,
        overflow: 'hidden',
    },
    input: {
        paddingHorizontal: Theme.spacing.md,
        paddingVertical: Theme.spacing.sm,
        fontSize: 15,
    },
});
