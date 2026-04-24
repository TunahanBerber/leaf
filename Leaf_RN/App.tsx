import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { AppNavigator } from './src/navigation/AppNavigator';

export default function App() {
  // LeafApp'teki scheme okuma mantığını (dark/light) hook ile AppNavigator'da da yapabiliriz.
  // Burada genel sağlayıcıları yapılandırıyoruz.

  return (
    <SafeAreaProvider>
      <StatusBar style="auto" />
      <AppNavigator />
    </SafeAreaProvider>
  );
}
