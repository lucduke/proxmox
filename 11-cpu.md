
# Gouverneur de CPU

## Récupérer la valeur actuelle

```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

## Visualiser les valeurs possibles

```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
```

## Spécifier une nouvelle valeur

```bash
echo "schedutil" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

## Appliquer la nouvelle valeur à chaque redémarrage via Cron

```bash
crontab -e

@reboot echo "schedutil" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1
```

