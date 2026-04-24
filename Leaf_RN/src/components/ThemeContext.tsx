import React, { createContext, useContext, useState, useEffect } from 'react';
import { DeviceEventEmitter } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

interface ThemeContextType {
    isDark: boolean;
    appTheme: string; // 'system' | 'light' | 'dark'
}

const ThemeContext = createContext<ThemeContextType>({ isDark: false, appTheme: 'system' });

export const useAppTheme = () => useContext(ThemeContext);

export const ThemeProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const [appTheme, setAppTheme] = useState('system');

    useEffect(() => {
        // Load persisted theme
        AsyncStorage.getItem('appTheme').then(val => {
            if (val) setAppTheme(val);
        });

        // Listen for changes from SettingsScreen
        const sub = DeviceEventEmitter.addListener('appThemeChanged', (newTheme: string) => {
            setAppTheme(newTheme);
        });
        return () => sub.remove();
    }, []);

    // For now, "system" defaults to light. On native you'd use Appearance API.
    const isDark = appTheme === 'dark';

    return (
        <ThemeContext.Provider value={{ isDark, appTheme }}>
            {children}
        </ThemeContext.Provider>
    );
};
