
package st.alr.mqttitude;

import java.io.IOException;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import st.alr.mqttitude.preferences.ActivityPreferences;
import st.alr.mqttitude.services.ServiceBindable;
import st.alr.mqttitude.services.ServiceLocator;
import st.alr.mqttitude.support.Events;
import st.alr.mqttitude.support.GeocodableLocation;
import st.alr.mqttitude.support.ReverseGeocodingTask;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.graphics.Bitmap;
import android.location.Address;
import android.location.Geocoder;
import android.location.Location;
import android.os.AsyncTask;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.google.android.gms.maps.CameraUpdate;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.GoogleMap.InfoWindowAdapter;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.Circle;
import com.google.android.gms.maps.model.CircleOptions;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;

import de.greenrobot.event.EventBus;

public class ActivityMain extends android.support.v4.app.FragmentActivity {
    MenuItem publish;
    TextView location;
    TextView statusLocator;
    TextView statusLastupdate;
    TextView statusServer;
    private GoogleMap mMap;

    private TextView locationPrimary;
    private TextView locationMeta;
    private LinearLayout locationAvailable;
    private LinearLayout locationUnavailable;

    private Marker mMarker;
    private Circle mCircle;
    private ServiceLocator serviceLocator;
    private ServiceConnection locatorConnection;
    private static Handler handler;
    
    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        int itemId = item.getItemId();
        if (itemId == R.id.menu_settings) {
            Intent intent1 = new Intent(this, ActivityPreferences.class);
            startActivity(intent1);
            return true;
        }  else if (itemId == R.id.menu_status) {
                Intent intent1 = new Intent(this, ActivityStatus.class);
                startActivity(intent1);
                return true;
        } else if (itemId == R.id.menu_publish) {           
            if(serviceLocator != null)
                serviceLocator.publishLastKnownLocation();
            return true;
        } else if (itemId == R.id.menu_share) {
            if(serviceLocator != null)
                this.share(null);
            return true;
        } else {
            return super.onOptionsItemSelected(item);
        }
    }

    private void setUpMapIfNeeded() {
        if (mMap == null) {
            mMap = ((com.google.android.gms.maps.SupportMapFragment) getSupportFragmentManager()
                    .findFragmentById(R.id.gmap)).getMap();
            if (mMap != null) {
                setUpMap();
            }
        }
    }

    private void setUpMap() {
        // Hide the zoom controls as the button panel will cover it.
        mMap.getUiSettings().setZoomControlsEnabled(false);
        mMap.setMyLocationEnabled(false);
        mMap.setTrafficEnabled(false);
        
    }

    @Override
    protected void onStart() {
        super.onStart();
        
        Log.v(this.toString(), "binding");

        
        locatorConnection = new ServiceConnection() {
            
            @Override
            public void onServiceDisconnected(ComponentName name) {
                serviceLocator = null;                
            }
            
            @Override
            public void onServiceConnected(ComponentName name, IBinder service) {
                Log.v(this.toString(), "bound");
                serviceLocator = (ServiceLocator) ((ServiceBindable.ServiceBinder)service).getService();                
            }
        };
        
        bindService(new Intent(this, App.getServiceLocatorClass()), locatorConnection, Context.BIND_AUTO_CREATE);
        EventBus.getDefault().registerSticky(this);
        
        if(serviceLocator != null)
            serviceLocator.enableForegroundMode();

    }
    
    @Override
    public void onStop() {
        unbindService(locatorConnection);
        EventBus.getDefault().unregister(this);

        if(serviceLocator != null)
            serviceLocator.enableBackgroundMode();

        super.onStop();
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        setUpMapIfNeeded();
    }

    @Override
    protected void onPause() {
        super.onPause();
    }

    @Override
    public void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.activity_main, menu);
        return true;
    }

    /**
     * @category START
     */
    @Override
    protected void onCreate(Bundle savedInstanceState) {

        super.onCreate(savedInstanceState);
        Log.v(this.toString(), "OnCreate");
        setContentView(R.layout.activity_main);
        setUpMapIfNeeded();

        serviceLocator = null;
        locationAvailable = (LinearLayout) findViewById(R.id.locationAvailable);
        locationUnavailable = (LinearLayout) findViewById(R.id.locationUnavailable);
        locationPrimary = (TextView) findViewById(R.id.locationPrimary);
        locationMeta = (TextView) findViewById(R.id.locationMeta);

        // Handler for updating text fields on the UI like the lat/long and address.
        handler = new Handler() {
            public void handleMessage(Message msg) {
                onHandlerMessage(msg);
            }
        };

        showLocationUnavailable();        
    }
    
    private void onHandlerMessage(Message msg) {
        switch (msg.what) {
            case ReverseGeocodingTask.GEOCODER_RESULT:
                Log.v(this.toString(), "Geocoder result_ " + ((GeocodableLocation) msg.obj).getGeocoder());
                locationPrimary.setText(((GeocodableLocation) msg.obj).getGeocoder());
                break;
            case ReverseGeocodingTask.GEOCODER_NORESULT:
                locationPrimary.setText(((GeocodableLocation) msg.obj).toLatLonString());

                break;

        }
    }   

    public void onEvent(Events.LocationUpdated e) {
        setLocation(e.getGeocodableLocation());
    }

    public void setLocation(GeocodableLocation location) {
        Location l = location.getLocation();
        Log.v(this.toString(), "Setting location");

       if(l == null) {
           Log.v(this.toString(), "location not available");
           showLocationUnavailable();
           return;
       } 
       
        LatLng latlong = new LatLng(l.getLatitude(), l.getLongitude());
        CameraUpdate center = CameraUpdateFactory.newLatLng(latlong);
        CameraUpdate zoom = CameraUpdateFactory.zoomTo(15);

        if (mMarker != null)
            mMarker.remove();

        if (mCircle != null)
            mCircle.remove();

        
        mMarker = mMap.addMarker(new MarkerOptions().position(latlong).icon(BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_AZURE)));
        
         if(l.getAccuracy() >= 50) {
                 mCircle = mMap.addCircle(new
                 CircleOptions().center(latlong).radius(l.getAccuracy()).strokeColor(0xff1082ac).fillColor(0x1c15bffe).strokeWidth(3));
         }

        mMap.moveCamera(center);
        mMap.animateCamera(zoom);

        if(location.getGeocoder() != null) {
            Log.v(this.toString(), "Reusing geocoder");
            locationPrimary.setText(location.getGeocoder());            
        } else {
            // Start async geocoder lookup and display latlon until geocoder reeturns something
            if (Geocoder.isPresent()) {
                Log.v(this.toString(), "Requesting geocoder");
                (new ReverseGeocodingTask(this, handler)).execute(new GeocodableLocation[] {location});
            
            } else {
                locationPrimary.setText(location.toLatLonString());                
            }
        }
        locationMeta.setText(App.getInstance().formatDate(new Date()));            

        showLocationAvailable();
    }

//    protected Bitmap adjustImage(Bitmap image) {
//        int dpi = image.getDensity();
//        if (dpi == mDpi)
//            return image;
//        else {
//            int width = (image.getWidth() * mDpi + dpi / 2) / dpi;
//            int height = (image.getHeight() * mDpi + dpi / 2) / dpi;
//            Bitmap adjustedImage = Bitmap.createScaledBitmap(image, width, height, true);
//            adjustedImage.setDensity(mDpi);
//            return adjustedImage;
//        }
//    }

    
    private void showLocationAvailable() {
        locationUnavailable.setVisibility(View.GONE);
        if(!locationAvailable.isShown())
            locationAvailable.setVisibility(View.VISIBLE);
    }

    private void showLocationUnavailable(){
        locationAvailable.setVisibility(View.GONE);
        if(!locationUnavailable.isShown())          
            locationUnavailable.setVisibility(View.VISIBLE);        
    }
    
    public void share(View view) {
        GeocodableLocation l = serviceLocator.getLastKnownLocation();
        if(l == null) {
            //TODO: signal to user
            return;            
        }
        
        Intent sendIntent = new Intent();
        sendIntent.setAction(Intent.ACTION_SEND);
        sendIntent.putExtra(
                Intent.EXTRA_TEXT,
                "http://maps.google.com/?q=" + Double.toString(l.getLatitude()) + ","
                        + Double.toString(l.getLongitude()));
        sendIntent.setType("text/plain");
        startActivity(Intent.createChooser(sendIntent,
                getResources().getText(R.string.shareLocation)));

    }

    public void upload(View view) {
            serviceLocator.publishLastKnownLocation();
    }
}
