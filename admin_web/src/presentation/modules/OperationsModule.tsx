import React, { useState, useEffect, useRef, useMemo } from 'react';
import {
  Navigation,
  Car,
  MapPin,
  Clock,
  User,
  Shield,
  Activity,
  AlertCircle,
  CheckCircle2,
  RefreshCw,
  Loader2,
  Phone,
  DollarSign,
  Compass,
  Radio,
  Send,
  XCircle,
  Eye,
  Check,
  Ban,
  ArrowRight,
  Flame,
  Cpu,
  Play,
  Pause,
  RotateCcw,
  FastForward,
  Gauge,
  BatteryCharging,
  Layers,
  Search,
  Crosshair,
  Sliders,
  Calendar,
  Sparkles
} from 'lucide-react';
import { 
  LiveTrackingRepository, 
  LiveDriverLocation, 
  DriverDailyRouteHistory,
  RouteBreadcrumbPoint,
  AL_QAIM_DISTRICTS
} from '../../infrastructure/repositories/LiveTrackingRepository';

declare const L: any; // Leaflet global loaded via CDN

export const OperationsModule: React.FC = () => {
  const mapContainerRef = useRef<HTMLDivElement | null>(null);
  const leafletMapRef = useRef<any>(null);
  const markersRef = useRef<Map<string, any>>(new Map());
  const activeRouteLayersRef = useRef<any[]>([]);
  const routePolylineRef = useRef<any>(null);
  const routeMarkersRef = useRef<any[]>([]);
  const playbackMarkerRef = useRef<any>(null);

  // Live Fleet State
  const [fleet, setFleet] = useState<LiveDriverLocation[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedDriver, setSelectedDriver] = useState<LiveDriverLocation | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'on_trip' | 'available' | 'offline'>('all');

  // Daily Route Tracing State
  const [selectedDate, setSelectedDate] = useState<string>(new Date().toISOString().split('T')[0]);
  const [isTracingRoute, setIsTracingRoute] = useState(false);
  const [routeHistory, setRouteHistory] = useState<DriverDailyRouteHistory | null>(null);
  const [isLoadingRoute, setIsLoadingRoute] = useState(false);

  // Playback Simulation State
  const [isPlaying, setIsPlaying] = useState(false);
  const [playbackIndex, setPlaybackIndex] = useState(0);
  const [playbackSpeed, setPlaybackSpeed] = useState<number>(1);
  const playbackTimerRef = useRef<any>(null);

  // Map Layer State (100% Free - Zero API Key Required)
  const [mapLayerType, setMapLayerType] = useState<'dark' | 'satellite' | 'street'>('dark');
  const tileLayerRef = useRef<any>(null);

  const [notification, setNotification] = useState<{ msg: string; type: 'success' | 'error' } | null>(null);

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setNotification({ msg, type });
    setTimeout(() => setNotification(null), 4000);
  };

  // 1. Initialize Interactive Leaflet Map & District Badges
  useEffect(() => {
    if (!mapContainerRef.current) return;
    if (leafletMapRef.current) return;

    if (typeof L === 'undefined') {
      console.warn('Leaflet not yet loaded from CDN');
      return;
    }

    try {
      // Initialize map centered at Al-Qaim
      const map = L.map(mapContainerRef.current, {
        center: [34.3644, 41.0117],
        zoom: 14,
        zoomControl: false,
        attributionControl: false
      });

      // 100% FREE OpenStreetMap Tiles with Dark Mode filter (Zero API Key Needed!)
      const baseTileLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        className: 'clean-dark-tiles'
      }).addTo(map);

      tileLayerRef.current = baseTileLayer;

      // Add Zoom Control to Top Left (RTL safe)
      L.control.zoom({ position: 'topleft' }).addTo(map);

      // Render Al-Qaim District Badges on Map
      AL_QAIM_DISTRICTS.forEach(dist => {
        const districtIcon = L.divIcon({
          className: 'custom-district-badge',
          html: `
            <div style="
              background: rgba(15, 23, 42, 0.7);
              backdrop-filter: blur(4px);
              border: 1px dashed rgba(6, 182, 212, 0.4);
              border-radius: 20px;
              padding: 2px 8px;
              color: #94a3b8;
              font-size: 10px;
              font-weight: 800;
              white-space: nowrap;
              box-shadow: 0 2px 8px rgba(0,0,0,0.4);
              cursor: pointer;
              display: flex;
              align-items: center;
              gap: 3px;
              transition: all 0.2s ease;
            ">
              <span style="color: #38bdf8; font-size: 9px;"></span>
              <span>${dist.name}</span>
            </div>
          `,
          iconSize: [110, 22],
          iconAnchor: [55, 11]
        });

        const dMarker = L.marker([dist.lat, dist.lng], { icon: districtIcon }).addTo(map);
        dMarker.on('click', () => {
          map.flyTo([dist.lat, dist.lng], 16, { duration: 1.0 });
        });
      });

      leafletMapRef.current = map;
    } catch (e) {
      console.error('Error initializing Leaflet map:', e);
    }

    return () => {
      if (leafletMapRef.current) {
        leafletMapRef.current.remove();
        leafletMapRef.current = null;
      }
    };
  }, []);

  // 1.1 Swap Tile Layers on the fly (Zero API Key)
  useEffect(() => {
    if (!leafletMapRef.current || typeof L === 'undefined') return;
    const map = leafletMapRef.current;

    if (tileLayerRef.current) {
      map.removeLayer(tileLayerRef.current);
    }

    let newLayer: any;
    if (mapLayerType === 'dark') {
      newLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        className: 'clean-dark-tiles'
      });
    } else if (mapLayerType === 'satellite') {
      newLayer = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
        maxZoom: 19
      });
    } else {
      newLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19
      });
    }

    newLayer.addTo(map);
    tileLayerRef.current = newLayer;
  }, [mapLayerType]);

  // 2. Subscribe to Real-Time Live Fleet Coordinates
  useEffect(() => {
    setIsLoading(true);
    const unsubscribe = LiveTrackingRepository.subscribeToLiveFleet((data) => {
      setFleet(data);
      setIsLoading(false);

      // Keep selected driver synced
      if (selectedDriver) {
        const updated = data.find(d => d.driverId === selectedDriver.driverId);
        if (updated) setSelectedDriver(updated);
      }
    });

    return () => unsubscribe();
  }, []);

  // 3. Render / Update Live Vehicle Markers on Leaflet Map
  useEffect(() => {
    if (!leafletMapRef.current || typeof L === 'undefined') return;
    const map = leafletMapRef.current;

    // Remove obsolete markers
    const currentDriverIds = new Set(fleet.map(d => d.driverId));
    markersRef.current.forEach((marker, id) => {
      if (!currentDriverIds.has(id)) {
        map.removeLayer(marker);
        markersRef.current.delete(id);
      }
    });

    // Create or update markers ONLY for drivers with valid real GPS coordinates from Firestore
    fleet.forEach((driver) => {
      if (!driver.hasValidGps) {
        if (markersRef.current.has(driver.driverId)) {
          map.removeLayer(markersRef.current.get(driver.driverId));
          markersRef.current.delete(driver.driverId);
        }
        return;
      }

      const isSelected = selectedDriver?.driverId === driver.driverId;
      const isOnline = driver.isOnline;
      const isOnTrip = driver.status === 'on_trip';

      const color = isOnTrip ? '#f59e0b' : (isOnline ? '#10b981' : '#64748b');
      const pulseHtml = isOnTrip || isOnline 
        ? `<div style="position: absolute; inset: -8px; border-radius: 50%; background: ${color}; opacity: 0.35; animation: ping 1.8s cubic-bezier(0, 0, 0.2, 1) infinite;"></div>`
        : '';

      const avatarContent = driver.personalPhotoUrl
        ? `<img src="${driver.personalPhotoUrl}" alt="${driver.driverName}" style="width: 100%; height: 100%; border-radius: 50%; object-fit: cover;" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';" /><div style="display: none; width: 100%; height: 100%; border-radius: 50%; background: #1e293b; color: #fff; font-weight: 900; font-size: 15px; align-items: center; justify-content: center;">${driver.driverName.charAt(0)}</div>`
        : `<div style="display: flex; width: 100%; height: 100%; border-radius: 50%; background: linear-gradient(135deg, #0f172a, #1e293b); color: #fff; font-weight: 900; font-size: 15px; align-items: center; justify-content: center;">${driver.driverName.charAt(0)}</div>`;

      const iconHtml = `
        <div style="position: relative; display: flex; flex-direction: column; align-items: center; cursor: pointer;">
          <!-- Glowing Captain Name & Speed Tag Floating Above -->
          <div style="
            background: rgba(15, 23, 42, 0.95);
            border: 1px solid ${color};
            box-shadow: 0 4px 14px rgba(0,0,0,0.5), 0 0 10px ${color}55;
            border-radius: 20px;
            padding: 3px 9px;
            display: flex;
            align-items: center;
            gap: 5px;
            white-space: nowrap;
            margin-bottom: 4px;
            transform: translateY(-2px);
          ">
            <span style="width: 7px; height: 7px; border-radius: 50%; background: ${color}; display: inline-block;"></span>
            <span style="font-size: 11px; font-weight: 900; color: #fff; font-family: 'IBM Plex Sans Arabic', sans-serif;">${driver.driverName}</span>
            <span style="font-size: 9.5px; font-weight: 800; color: #38bdf8; background: rgba(56, 189, 248, 0.15); padding: 1px 5px; border-radius: 6px;">${driver.speedKmh} كم/س</span>
          </div>

          <!-- Driver Photo Pin with Corner Vehicle Badge -->
          <div style="position: relative; width: 44px; height: 44px; display: flex; align-items: center; justify-content: center;">
            ${pulseHtml}
            <div style="
              position: relative;
              width: 40px; 
              height: 40px; 
              border-radius: 50%; 
              background: ${isSelected ? '#0284c7' : '#0f172a'}; 
              border: 2.5px solid ${color}; 
              display: flex; 
              align-items: center; 
              justify-content: center; 
              box-shadow: 0 0 16px ${color}aa;
              overflow: visible;
              transition: all 0.3s ease;
            ">
              ${avatarContent}
              <!-- Corner Vehicle Mini Badge -->
              <div style="
                position: absolute;
                bottom: -2px;
                right: -2px;
                width: 18px;
                height: 18px;
                border-radius: 50%;
                background: #0f172a;
                border: 1.5px solid ${color};
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 10px;
                box-shadow: 0 2px 5px rgba(0,0,0,0.6);
              ">
                ${driver.serviceType === 'delivery' ? '' : ''}
              </div>
            </div>
          </div>

          <!-- Location Street Label Below -->
          <div style="
            background: rgba(15, 23, 42, 0.85);
            border: 1px solid rgba(255,255,255,0.08);
            border-radius: 6px;
            padding: 1px 6px;
            font-size: 9.5px;
            color: #94a3b8;
            margin-top: 2px;
            white-space: nowrap;
          ">
             ${driver.currentLocationName}
          </div>
        </div>
      `;

      const customIcon = L.divIcon({
        className: 'custom-driver-pin',
        html: iconHtml,
        iconSize: [140, 75],
        iconAnchor: [70, 38]
      });

      if (markersRef.current.has(driver.driverId)) {
        const marker = markersRef.current.get(driver.driverId);
        marker.setLatLng([driver.latitude, driver.longitude]);
        marker.setIcon(customIcon);
      } else {
        const marker = L.marker([driver.latitude, driver.longitude], { icon: customIcon }).addTo(map);
        
        // Rich Driver Info Popup on Marker Click
        const popupContent = `
          <div style="direction: rtl; text-align: right; font-family: 'IBM Plex Sans Arabic', sans-serif; min-width: 200px; padding: 4px;">
            <div style="display: flex; align-items: center; gap: 8px; border-bottom: 1px solid #e2e8f0; padding-bottom: 6px; margin-bottom: 8px;">
              <div style="font-size: 20px;">${driver.serviceType === 'delivery' ? '' : ''}</div>
              <div>
                <div style="font-weight: 900; font-size: 14px; color: #0f172a;">${driver.driverName}</div>
                <div style="font-size: 11px; color: #64748b;" dir="ltr"> ${driver.driverPhone}</div>
              </div>
            </div>
            <div style="font-size: 12px; display: flex; flex-direction: column; gap: 4px; color: #334155;">
              <div> <b>الموقع الحقيقي:</b> ${driver.currentLocationName}</div>
              <div> <b>الإحداثيات:</b> ${driver.coordinatesFormatted}</div>
              <div> <b>المركبة:</b> ${driver.vehicleModel} (${driver.vehiclePlate})</div>
              <div> <b>السرعة الحقيقية:</b> <span style="color: #0284c7; font-weight: 800;">${driver.speedKmh} كم/س</span></div>
              <div> <b>حالة الاتصال:</b> <span style="color: ${color}; font-weight: 800;">${driver.status === 'on_trip' ? 'في رحلة نشطة ' : (driver.isOnline ? 'متاح وجاهز ' : 'غير متصل')}</span></div>
            </div>
          </div>
        `;
        marker.bindPopup(popupContent);

        marker.on('click', () => {
          setSelectedDriver(driver);
          map.panTo([driver.latitude, driver.longitude], { animate: true, duration: 0.8 });
        });
        markersRef.current.set(driver.driverId, marker);
      }
    });
  }, [fleet, selectedDriver?.driverId]);

  // 3.1 Render Active Trip Route (Pickup -> Driver -> Dropoff)
  useEffect(() => {
    if (!leafletMapRef.current || typeof L === 'undefined') return;
    const map = leafletMapRef.current;

    // Clear previous active route layers
    activeRouteLayersRef.current.forEach(layer => map.removeLayer(layer));
    activeRouteLayersRef.current = [];

    const targetDriver = selectedDriver || fleet.find(d => d.status === 'on_trip' && d.activeTrip);
    if (!targetDriver || !targetDriver.activeTrip) return;

    const trip = targetDriver.activeTrip;
    const pathCoordinates: [number, number][] = [
      [trip.pickupLat, trip.pickupLng],
      [targetDriver.latitude, targetDriver.longitude],
      [trip.dropoffLat, trip.dropoffLng]
    ];

    // Glowing Polyline for the active trip
    const routeLine = L.polyline(pathCoordinates, {
      color: '#06b6d4',
      weight: 4,
      opacity: 0.85,
      dashArray: '7, 7',
      lineCap: 'round',
      lineJoin: 'round'
    }).addTo(map);

    // Pickup Pin Badge
    const pickupIcon = L.divIcon({
      className: 'pickup-pin',
      html: `
        <div style="background: rgba(16, 185, 129, 0.95); color: #fff; font-size: 10px; font-weight: 900; padding: 3px 8px; border-radius: 12px; white-space: nowrap; box-shadow: 0 0 10px rgba(16, 185, 129, 0.6); border: 1.5px solid #fff; display: flex; align-items: center; gap: 4px; font-family: 'IBM Plex Sans Arabic', sans-serif;">
          <span> نقطة الانطلاق:</span> <span>${trip.pickupAddress}</span>
        </div>
      `,
      iconSize: [160, 24],
      iconAnchor: [80, 12]
    });
    const pickupMarker = L.marker([trip.pickupLat, trip.pickupLng], { icon: pickupIcon }).addTo(map);

    // Dropoff Pin Badge
    const dropoffIcon = L.divIcon({
      className: 'dropoff-pin',
      html: `
        <div style="background: rgba(239, 68, 68, 0.95); color: #fff; font-size: 10px; font-weight: 900; padding: 3px 8px; border-radius: 12px; white-space: nowrap; box-shadow: 0 0 10px rgba(239, 68, 68, 0.6); border: 1.5px solid #fff; display: flex; align-items: center; gap: 4px; font-family: 'IBM Plex Sans Arabic', sans-serif;">
          <span> الوجهة:</span> <span>${trip.dropoffAddress}</span>
        </div>
      `,
      iconSize: [160, 24],
      iconAnchor: [80, 12]
    });
    const dropoffMarker = L.marker([trip.dropoffLat, trip.dropoffLng], { icon: dropoffIcon }).addTo(map);

    activeRouteLayersRef.current = [routeLine, pickupMarker, dropoffMarker];
  }, [selectedDriver, fleet]);

  // 4. Focus on driver coordinates
  const handleFocusDriver = (driver: LiveDriverLocation) => {
    setSelectedDriver(driver);
    if (!driver.hasValidGps) {
      showToast(`الكابتن (${driver.driverName}) لم يرسل إحداثيات GPS حية بعد من تطبيقه.`, 'error');
      return;
    }
    if (leafletMapRef.current) {
      leafletMapRef.current.flyTo([driver.latitude, driver.longitude], 16, { duration: 1.2 });
    }
  };

  // 5. Reset Map to Al-Qaim Center
  const handleResetMapCenter = () => {
    if (leafletMapRef.current) {
      leafletMapRef.current.flyTo([34.3644, 41.0117], 14, { duration: 1.0 });
    }
  };

  // 6. Trace & Render Real Daily GPS Route
  const handleTraceDailyRoute = async (driver: LiveDriverLocation) => {
    setIsLoadingRoute(true);
    setIsTracingRoute(true);
    setIsPlaying(false);
    setPlaybackIndex(0);

    try {
      const history = await LiveTrackingRepository.getDriverDailyRouteHistory(driver.driverId, selectedDate);
      setRouteHistory(history);

      if (leafletMapRef.current && typeof L !== 'undefined') {
        const map = leafletMapRef.current;

        // Clear existing route polyline and milestones
        if (routePolylineRef.current) map.removeLayer(routePolylineRef.current);
        routeMarkersRef.current.forEach(m => map.removeLayer(m));
        routeMarkersRef.current = [];
        if (playbackMarkerRef.current) map.removeLayer(playbackMarkerRef.current);

        if (history.points.length === 0) {
          showToast(`لا توجد نقاط مسار GPS مسجلة لهذا السائق في قاعدة البيانات لتاريخ ${selectedDate}`, 'error');
          return;
        }

        const latLngs = history.points.map(p => [p.latitude, p.longitude]);

        // Draw Glowing Route Polyline
        const polyline = L.polyline(latLngs, {
          color: '#38bdf8',
          weight: 5,
          opacity: 0.85,
          dashArray: '8, 8',
          lineCap: 'round'
        }).addTo(map);
        routePolylineRef.current = polyline;

        // Add Stop / Milestone Markers
        history.points.forEach((p, idx) => {
          if (p.isStopPoint || idx === 0 || idx === history.points.length - 1) {
            const isStart = idx === 0;
            const isEnd = idx === history.points.length - 1;
            const stopColor = isStart ? '#10b981' : (isEnd ? '#ef4444' : '#f59e0b');

            const stopIconHtml = `
              <div style="background: ${stopColor}; color: #000; border: 2px solid #fff; border-radius: 50%; width: 22px; height: 22px; display: flex; align-items: center; justify-content: center; font-size: 10px; font-weight: 900; box-shadow: 0 0 10px ${stopColor};">
                ${isStart ? '' : (isEnd ? '' : `${idx}`)}
              </div>
            `;

            const marker = L.marker([p.latitude, p.longitude], {
              icon: L.divIcon({
                className: 'stop-pin',
                html: stopIconHtml,
                iconSize: [22, 22],
                iconAnchor: [11, 11]
              })
            }).addTo(map);

            marker.bindPopup(`
              <div style="direction: rtl; font-family: 'IBM Plex Sans Arabic', sans-serif; font-size: 12px; color: #0f172a;">
                <div style="font-weight: 800; font-size: 13px; color: #0284c7;">${p.streetName}</div>
                <div style="margin-top: 3px;"> الوقت: <b>${p.timeFormatted}</b></div>
                <div> السرعة: <b>${p.speedKmh} كم/س</b></div>
              </div>
            `);

            routeMarkersRef.current.push(marker);
          }
        });

        // Fit map bounds to view full route
        map.fitBounds(polyline.getBounds(), { padding: [50, 50] });
        showToast(`تم استدعاء مسار GPS الحقيقي لتاريخ ${selectedDate} بنجاح `);
      }
    } catch (err: any) {
      showToast('تعذر جلب المسار من قاعدة البيانات: ' + (err.message || ''), 'error');
    } finally {
      setIsLoadingRoute(false);
    }
  };

  // 7. Clear Route Tracing
  const handleClearRoute = () => {
    if (leafletMapRef.current) {
      const map = leafletMapRef.current;
      if (routePolylineRef.current) map.removeLayer(routePolylineRef.current);
      routeMarkersRef.current.forEach(m => map.removeLayer(m));
      routeMarkersRef.current = [];
      if (playbackMarkerRef.current) map.removeLayer(playbackMarkerRef.current);
    }
    setIsTracingRoute(false);
    setRouteHistory(null);
    setIsPlaying(false);
    setPlaybackIndex(0);
  };

  // 8. GPS Route Motion Playback Simulation Loop
  useEffect(() => {
    if (!isPlaying || !routeHistory || routeHistory.points.length === 0) {
      clearInterval(playbackTimerRef.current);
      return;
    }

    playbackTimerRef.current = setInterval(() => {
      setPlaybackIndex((prevIndex) => {
        const nextIndex = prevIndex + 1;
        if (nextIndex >= routeHistory.points.length) {
          setIsPlaying(false);
          return prevIndex;
        }

        const point = routeHistory.points[nextIndex];
        if (leafletMapRef.current && typeof L !== 'undefined') {
          const map = leafletMapRef.current;

          // Update or create simulation vehicle marker
          if (!playbackMarkerRef.current) {
            const simIcon = L.divIcon({
              className: 'sim-vehicle',
              html: `
                <div style="width: 36px; height: 36px; border-radius: 50%; background: #0284c7; border: 3px solid #38bdf8; display: flex; align-items: center; justify-content: center; font-size: 18px; box-shadow: 0 0 20px #38bdf8;">
                  
                </div>
              `,
              iconSize: [36, 36],
              iconAnchor: [18, 18]
            });
            playbackMarkerRef.current = L.marker([point.latitude, point.longitude], { icon: simIcon }).addTo(map);
          } else {
            playbackMarkerRef.current.setLatLng([point.latitude, point.longitude]);
          }

          map.panTo([point.latitude, point.longitude], { animate: true, duration: 0.4 });
        }

        return nextIndex;
      });
    }, 1200 / playbackSpeed);

    return () => clearInterval(playbackTimerRef.current);
  }, [isPlaying, routeHistory, playbackSpeed]);

  // Filtered Fleet
  const filteredFleet = useMemo(() => {
    return fleet.filter((d) => {
      if (statusFilter === 'on_trip' && d.status !== 'on_trip') return false;
      if (statusFilter === 'available' && d.status !== 'available') return false;
      if (statusFilter === 'offline' && d.status !== 'offline') return false;

      const q = searchQuery.toLowerCase().trim();
      if (!q) return true;
      return (
        d.driverName.toLowerCase().includes(q) ||
        d.driverPhone.includes(q) ||
        d.vehiclePlate.includes(q)
      );
    });
  }, [fleet, statusFilter, searchQuery]);

  const onlineCount = fleet.filter(d => d.isOnline).length;
  const onTripCount = fleet.filter(d => d.status === 'on_trip').length;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', height: 'calc(100vh - 120px)' }}>
      
      {/* Toast Notification */}
      {notification && (
        <div style={{ position: 'fixed', top: '85px', left: '30px', zIndex: 9999, background: notification.type === 'success' ? 'rgba(16, 185, 129, 0.95)' : 'rgba(239, 68, 68, 0.95)', color: '#fff', padding: '12px 20px', borderRadius: '12px', boxShadow: '0 10px 30px rgba(0,0,0,0.4)', fontWeight: '700', fontSize: '13px' }}>
          {notification.msg}
        </div>
      )}

      {/* Top Operations Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h2 style={{ fontSize: '20px', fontWeight: '900', color: '#fff', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: 'linear-gradient(135deg, #06b6d4, #0284c7)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
              <Navigation size={20} />
            </div>
            <span>الخريطة التفاعلية الحية وتتبع مسارات السائقين اللحظية (Live GPS Radar)</span>
          </h2>
          <p style={{ fontSize: '12.5px', color: 'var(--text-muted)', marginTop: '2px' }}>
            رادار حي مباشر لرصد حركة وتوزيع كباتن التكسي والتوصيل في القائم مع تحديد ورسم خطوط السير اليومية
          </p>
        </div>

        {/* Live Counters */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', padding: '6px 14px', borderRadius: '20px', background: 'rgba(16, 185, 129, 0.15)', border: '1px solid rgba(16, 185, 129, 0.3)', color: '#34d399', fontSize: '12px', fontWeight: '800' }}>
            <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#34d399', animation: 'pulse 1.5s infinite' }} />
            <span>{onlineCount} كابتن متصل</span>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', padding: '6px 14px', borderRadius: '20px', background: 'rgba(245, 158, 11, 0.15)', border: '1px solid rgba(245, 158, 11, 0.3)', color: '#fbbf24', fontSize: '12px', fontWeight: '800' }}>
            <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#fbbf24' }} />
            <span>{onTripCount} في رحلة وتوصيل نشط</span>
          </div>

          <button onClick={handleResetMapCenter} className="btn btn-secondary" style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Crosshair size={14} /> إعادة ضبط الخريطة (القائم)
          </button>
        </div>
      </div>

      {/* ─── MAIN DUAL LAYOUT: INTERACTIVE MAP (LEFT) & FLEET CONTROLLER (RIGHT) ─── */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 360px', gap: '16px', flex: 1, minHeight: 0 }}>
        
        {/* MAP VIEWPORT */}
        <div style={{ position: 'relative', borderRadius: '20px', overflow: 'hidden', border: '1px solid rgba(6, 182, 212, 0.3)', background: '#090d16' }}>
          
          {/* Leaflet DOM Node */}
          <div ref={mapContainerRef} style={{ width: '100%', height: '100%' }} />

          {/* Floating Map Controls & Compass Overlay */}
          <div style={{ position: 'absolute', top: '16px', right: '16px', zIndex: 1000, display: 'flex', flexDirection: 'column', gap: '8px' }}>
            <div style={{ background: 'rgba(15, 23, 42, 0.9)', backdropFilter: 'blur(8px)', border: '1px solid var(--border-color)', borderRadius: '12px', padding: '8px 14px', display: 'flex', alignItems: 'center', gap: '8px', color: '#fff', fontSize: '12px', fontWeight: '800' }}>
              <Compass size={16} color="#06b6d4" />
              <span>قطاع القائم المركزي </span>
            </div>

            {/* Free Layer Switcher Toolbar (Zero API Key) */}
            <div style={{ background: 'rgba(15, 23, 42, 0.9)', backdropFilter: 'blur(8px)', border: '1px solid var(--border-color)', borderRadius: '12px', padding: '4px', display: 'flex', gap: '4px' }}>
              <button
                onClick={() => setMapLayerType('dark')}
                className={`btn ${mapLayerType === 'dark' ? 'btn-primary' : 'btn-secondary'}`}
                style={{ fontSize: '11px', padding: '4px 8px', borderRadius: '8px' }}
                title="خريطة مدار الليلية (مجانية بدون مفتاح)"
              >
                 ليلية
              </button>
              <button
                onClick={() => setMapLayerType('satellite')}
                className={`btn ${mapLayerType === 'satellite' ? 'btn-primary' : 'btn-secondary'}`}
                style={{ fontSize: '11px', padding: '4px 8px', borderRadius: '8px' }}
                title="صور أقمار صناعية عالية الدقة (مجانية بدون مفتاح)"
              >
                 قمر صناعي
              </button>
              <button
                onClick={() => setMapLayerType('street')}
                className={`btn ${mapLayerType === 'street' ? 'btn-primary' : 'btn-secondary'}`}
                style={{ fontSize: '11px', padding: '4px 8px', borderRadius: '8px' }}
                title="خريطة الشوارع الواضحة"
              >
                 شوارع
              </button>
            </div>
          </div>

          {/* ─── ROUTE PLAYBACK & TIMELINE CONTROLLER (When Tracing Route) ─── */}
          {isTracingRoute && routeHistory && (
            <div style={{ position: 'absolute', bottom: '16px', left: '16px', right: '16px', zIndex: 1000, background: 'rgba(15, 23, 42, 0.95)', backdropFilter: 'blur(10px)', border: '1px solid rgba(56, 189, 248, 0.4)', borderRadius: '16px', padding: '14px 20px', display: 'flex', flexDirection: 'column', gap: '10px' }}>
              
              {/* Route Summary Stats */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '10px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <span style={{ fontWeight: '900', color: '#38bdf8', fontSize: '14px' }}>
                    مسار حركة: {selectedDriver?.driverName} ({routeHistory.date})
                  </span>
                  <span style={{ fontSize: '11px', color: '#34d399', background: 'rgba(16, 185, 129, 0.15)', padding: '2px 8px', borderRadius: '6px', fontWeight: '800' }}>
                    المسافة: {routeHistory.totalDistanceKm} كم
                  </span>
                  <span style={{ fontSize: '11px', color: '#fbbf24', background: 'rgba(245, 158, 11, 0.15)', padding: '2px 8px', borderRadius: '6px', fontWeight: '800' }}>
                    المدة: {routeHistory.totalDurationMinutes} دقيقة
                  </span>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <button onClick={handleClearRoute} className="btn btn-secondary" style={{ fontSize: '11.5px', padding: '4px 10px', color: '#f87171' }}>
                    إلغاء تتبع المسار 
                  </button>
                </div>
              </div>

              {/* Progress Slider & Simulation Controls */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                <button
                  onClick={() => setIsPlaying(!isPlaying)}
                  className="btn btn-primary"
                  style={{ width: '36px', height: '36px', borderRadius: '50%', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'linear-gradient(135deg, #0284c7, #0369a1)', borderColor: '#38bdf8' }}
                >
                  {isPlaying ? <Pause size={16} /> : <Play size={16} />}
                </button>

                <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
                  <input
                    type="range"
                    min="0"
                    max={routeHistory.points.length - 1}
                    value={playbackIndex}
                    onChange={(e) => {
                      const idx = Number(e.target.value);
                      setPlaybackIndex(idx);
                      const pt = routeHistory.points[idx];
                      if (playbackMarkerRef.current && pt) {
                        playbackMarkerRef.current.setLatLng([pt.latitude, pt.longitude]);
                        leafletMapRef.current?.panTo([pt.latitude, pt.longitude]);
                      }
                    }}
                    style={{ width: '100%', accentColor: '#38bdf8', cursor: 'pointer' }}
                  />
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px', color: 'var(--text-muted)' }}>
                    <span>نقطة الانطلاق (08:00 ص)</span>
                    <span style={{ color: '#38bdf8', fontWeight: '800' }}>
                      {routeHistory.points[playbackIndex]?.streetName || ''} • {routeHistory.points[playbackIndex]?.timeFormatted || ''} • {routeHistory.points[playbackIndex]?.speedKmh || 0} كم/س
                    </span>
                    <span>الموقع الحالي</span>
                  </div>
                </div>

                {/* Speed Multiplier */}
                <div style={{ display: 'flex', gap: '3px' }}>
                  {[1, 2, 5].map((spd) => (
                    <button
                      key={spd}
                      onClick={() => setPlaybackSpeed(spd)}
                      className={`btn ${playbackSpeed === spd ? 'btn-primary' : 'btn-secondary'}`}
                      style={{ fontSize: '10px', padding: '3px 7px' }}
                    >
                      {spd}x
                    </button>
                  ))}
                </div>
              </div>

            </div>
          )}

        </div>

        {/* RIGHT: FLEET RADAR CONTROLLER & DRIVER DOSSIER */}
        <div className="glass-panel" style={{ padding: '14px', display: 'flex', flexDirection: 'column', gap: '12px', overflow: 'hidden' }}>
          
          {/* Search & Filters */}
          <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
            <Search size={15} color="#94a3b8" style={{ position: 'absolute', right: '10px' }} />
            <input
              type="text"
              placeholder="ابحث عن كابتن أو رقم سيارة..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              style={{ width: '100%', padding: '8px 32px 8px 10px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '8px', color: '#fff', fontSize: '12px', outline: 'none' }}
            />
          </div>

          <div style={{ display: 'flex', gap: '4px', overflowX: 'auto', paddingBottom: '2px' }}>
            <button onClick={() => setStatusFilter('all')} className={`btn ${statusFilter === 'all' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '11px', padding: '4px 8px' }}>الكل ({fleet.length})</button>
            <button onClick={() => setStatusFilter('on_trip')} className={`btn ${statusFilter === 'on_trip' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '11px', padding: '4px 8px', color: '#fbbf24' }}>في رحلة ({onTripCount})</button>
            <button onClick={() => setStatusFilter('available')} className={`btn ${statusFilter === 'available' ? 'btn-primary' : 'btn-secondary'}`} style={{ fontSize: '11px', padding: '4px 8px', color: '#34d399' }}>متاح</button>
          </div>

          {/* Selected Driver Detailed Dossier */}
          {selectedDriver ? (
            <div style={{ background: 'rgba(15, 23, 42, 0.95)', border: '1px solid rgba(6, 182, 212, 0.4)', borderRadius: '14px', padding: '12px', display: 'flex', flexDirection: 'column', gap: '10px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  {selectedDriver.personalPhotoUrl ? (
                    <img
                      src={selectedDriver.personalPhotoUrl}
                      alt={selectedDriver.driverName}
                      style={{ width: '40px', height: '40px', borderRadius: '50%', objectFit: 'cover', border: '2px solid #06b6d4' }}
                      onError={(e) => { (e.target as any).style.display = 'none'; }}
                    />
                  ) : (
                    <div style={{ width: '40px', height: '40px', borderRadius: '50%', background: 'rgba(6, 182, 212, 0.2)', color: '#38bdf8', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: '900', fontSize: '15px', border: '1px solid rgba(6, 182, 212, 0.4)' }}>
                      {selectedDriver.driverName.charAt(0)}
                    </div>
                  )}
                  <div>
                    <div style={{ fontWeight: '900', color: '#fff', fontSize: '13.5px' }}>{selectedDriver.driverName}</div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)' }} dir="ltr">{selectedDriver.driverPhone}</div>
                  </div>
                </div>

                <button onClick={() => setSelectedDriver(null)} style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer' }}></button>
              </div>

              {/* Telemetry Metrics */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '6px' }}>
                <div style={{ background: 'rgba(255,255,255,0.02)', padding: '6px', borderRadius: '8px', textAlign: 'center' }}>
                  <div style={{ fontSize: '10px', color: 'var(--text-dim)' }}>السرعة اللحظية</div>
                  <div style={{ fontSize: '13px', fontWeight: '900', color: '#38bdf8' }}>{selectedDriver.speedKmh} <span style={{ fontSize: '9px' }}>كم/س</span></div>
                </div>

                <div style={{ background: 'rgba(255,255,255,0.02)', padding: '6px', borderRadius: '8px', textAlign: 'center' }}>
                  <div style={{ fontSize: '10px', color: 'var(--text-dim)' }}>إجمالي الرحلات</div>
                  <div style={{ fontSize: '13px', fontWeight: '900', color: '#34d399' }}>{selectedDriver.todayCompletedTrips}</div>
                </div>

                <div style={{ background: 'rgba(255,255,255,0.02)', padding: '6px', borderRadius: '8px', textAlign: 'center' }}>
                  <div style={{ fontSize: '10px', color: 'var(--text-dim)' }}>شحن البطارية</div>
                  <div style={{ fontSize: '13px', fontWeight: '900', color: '#fbbf24' }}>
                    {selectedDriver.batteryLevel !== undefined ? `${selectedDriver.batteryLevel}% ` : '—'}
                  </div>
                </div>
              </div>

              {/* Current Location & Destination Box */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', background: 'rgba(6, 182, 212, 0.08)', border: '1px solid rgba(6, 182, 212, 0.25)', borderRadius: '10px', padding: '8px 10px' }}>
                <div style={{ fontSize: '11.5px', color: '#38bdf8', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <MapPin size={13} />
                  <span>الموقع: <b>{selectedDriver.currentLocationName}</b></span>
                </div>
                <div style={{ fontSize: '10.5px', color: selectedDriver.hasValidGps ? 'var(--text-dim)' : '#f87171' }} dir="ltr">
                   {selectedDriver.coordinatesFormatted}
                </div>
                {selectedDriver.currentDestination && (
                  <div style={{ fontSize: '11px', color: '#fbbf24', marginTop: '2px', borderTop: '1px dashed rgba(255,255,255,0.1)', paddingTop: '4px' }}>
                     الوجهة: <b>{selectedDriver.currentDestination}</b>
                  </div>
                )}
              </div>

              {/* Date Selector & Trace Daily Route Button */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', marginTop: '2px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Calendar size={13} color="#94a3b8" />
                  <input
                    type="date"
                    value={selectedDate}
                    onChange={e => setSelectedDate(e.target.value)}
                    style={{ flex: 1, padding: '4px 8px', background: '#0f172a', border: '1px solid var(--border-color)', borderRadius: '6px', color: '#fff', fontSize: '11.5px' }}
                  />
                </div>

                <button
                  onClick={() => handleTraceDailyRoute(selectedDriver)}
                  disabled={isLoadingRoute}
                  className="btn btn-primary"
                  style={{ fontSize: '12px', padding: '8px 12px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px', background: 'linear-gradient(135deg, #0284c7, #0369a1)', borderColor: '#38bdf8', fontWeight: '800' }}
                >
                  {isLoadingRoute ? <Loader2 size={14} style={{ animation: 'spin 1s linear infinite' }} /> : <Sparkles size={14} />}
                  <span>استدعاء مسار GPS الحقيقي </span>
                </button>
              </div>
            </div>
          ) : null}

          {/* Fleet Drivers List */}
          <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '6px' }}>
            {isLoading ? (
              <div style={{ padding: '30px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <Loader2 size={20} color="#06b6d4" style={{ animation: 'spin 1s linear infinite', margin: '0 auto 6px' }} />
                <div style={{ fontSize: '12px' }}>جاري استدعاء إحداثيات ومواقع الأسطول من Firestore...</div>
              </div>
            ) : filteredFleet.length === 0 ? (
              <div style={{ padding: '30px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <Car size={24} color="#64748b" style={{ margin: '0 auto 6px' }} />
                <div style={{ fontSize: '12.5px', color: '#fff', fontWeight: '700' }}>ماكو كباتن حالياً مسجلين</div>
              </div>
            ) : (
              filteredFleet.map((d) => {
                const isSelected = selectedDriver?.driverId === d.driverId;
                const isOnTrip = d.status === 'on_trip';
                const isOnline = d.isOnline;

                return (
                  <div
                    key={d.driverId}
                    onClick={() => handleFocusDriver(d)}
                    style={{
                      padding: '10px 12px',
                      borderRadius: '10px',
                      background: isSelected ? 'linear-gradient(135deg, rgba(6, 182, 212, 0.2), rgba(2, 132, 199, 0.2))' : 'rgba(255, 255, 255, 0.02)',
                      border: isSelected ? '1px solid #06b6d4' : '1px solid rgba(255, 255, 255, 0.05)',
                      cursor: 'pointer',
                      transition: 'all 0.15s ease',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      gap: '8px'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', overflow: 'hidden' }}>
                      <div style={{ position: 'relative', width: '36px', height: '36px', flexShrink: 0 }}>
                        {d.personalPhotoUrl ? (
                          <img
                            src={d.personalPhotoUrl}
                            alt={d.driverName}
                            style={{ width: '36px', height: '36px', borderRadius: '50%', objectFit: 'cover', border: `1.5px solid ${isOnTrip ? '#fbbf24' : (isOnline ? '#10b981' : '#64748b')}` }}
                            onError={(e) => { (e.target as any).style.display = 'none'; }}
                          />
                        ) : (
                          <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: isOnTrip ? 'rgba(245, 158, 11, 0.2)' : (isOnline ? 'rgba(16, 185, 129, 0.2)' : 'rgba(100, 116, 139, 0.2)'), color: isOnTrip ? '#fbbf24' : (isOnline ? '#34d399' : '#94a3b8'), display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '13px', fontWeight: '800', border: '1px solid rgba(255,255,255,0.1)' }}>
                            {d.driverName.charAt(0)}
                          </div>
                        )}
                        {/* Mini vehicle corner badge */}
                        <div style={{ position: 'absolute', bottom: '-2px', right: '-2px', width: '15px', height: '15px', borderRadius: '50%', background: '#0f172a', border: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '8px' }}>
                          {d.serviceType === 'delivery' ? '' : ''}
                        </div>
                      </div>
                      <div style={{ overflow: 'hidden' }}>
                        <div style={{ fontWeight: '800', color: '#fff', fontSize: '13px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          {d.driverName}
                        </div>
                        <div style={{ fontSize: '11px', color: d.hasValidGps ? '#38bdf8' : '#94a3b8', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', display: 'flex', alignItems: 'center', gap: '3px', marginTop: '1px' }}>
                          <MapPin size={10} color={d.hasValidGps ? '#38bdf8' : '#64748b'} />
                          <span>{d.currentLocationName}</span>
                        </div>
                        <div style={{ fontSize: '10px', color: 'var(--text-dim)', marginTop: '1px' }}>
                          {d.vehicleModel} • {d.vehiclePlate}
                        </div>
                      </div>
                    </div>

                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '3px', flexShrink: 0 }}>
                      <span style={{ fontSize: '10px', padding: '1px 6px', borderRadius: '6px', background: isOnTrip ? 'rgba(245, 158, 11, 0.2)' : (isOnline ? 'rgba(16, 185, 129, 0.2)' : 'rgba(100, 116, 139, 0.2)'), color: isOnTrip ? '#fbbf24' : (isOnline ? '#34d399' : '#94a3b8'), fontWeight: '800' }}>
                        {isOnTrip ? 'في رحلة ' : (isOnline ? 'متاح ' : 'غير متصل')}
                      </span>
                      {d.hasValidGps ? (
                        <span style={{ fontSize: '11px', color: '#34d399', fontWeight: '900' }}>{d.speedKmh} كم/س</span>
                      ) : (
                        <span style={{ fontSize: '9.5px', color: '#64748b' }}>بدون إشارة GPS</span>
                      )}
                    </div>
                  </div>
                );
              })
            )}
          </div>

        </div>

      </div>

    </div>
  );
};
