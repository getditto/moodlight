package live.ditto.moodlight

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.TextView
import android.widget.ToggleButton
import androidx.appcompat.app.AppCompatActivity
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.content.ContextCompat
import live.ditto.*
import live.ditto.android.DefaultAndroidDittoDependencies
import live.ditto.transports.DittoSyncPermissions
import yuku.ambilwarna.AmbilWarnaDialog
import kotlin.properties.Delegates
import kotlin.random.Random.Default.nextInt

class MainActivity : AppCompatActivity() {
    lateinit var mLayout: ConstraintLayout
    var mDefaultColor by Delegates.notNull<Int>()
    private lateinit var mButton: Button
    private lateinit var mTextView: TextView
    private lateinit var mLightSwitch: ToggleButton
    private var isOff = false
    private lateinit var ditto: Ditto
    private lateinit var collection: DittoCollection
    private lateinit var liveQuery: DittoLiveQuery

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        this.mLayout = findViewById(R.id.layout)
        this.mDefaultColor = ContextCompat.getColor(this, R.color.purple_200)
        this.mLayout.setBackgroundColor(mDefaultColor)
        this.mLayout.setOnClickListener {
            val color = Color.rgb(nextInt(0, 255), nextInt(0,255), nextInt(0,255))
            val red = Color.red(color)
            val green = Color.green(color)
            val blue = Color.blue(color)

            ditto.store["lights"].upsert(
                mapOf(
                    "_id" to 5,
                    "red" to red,
                    "green" to green,
                    "blue" to blue,
                    "isOff" to false
                )
            )
        }
        this.mTextView = findViewById(R.id.textview)
        this.mTextView.setTextColor(Color.WHITE)
        this.mTextView.textSize = 22.0F
        this.mTextView.gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER_HORIZONTAL
        this.mButton = findViewById(R.id.button)
        this.mButton.setOnClickListener { openColorPicker(); }
        this.mLightSwitch = findViewById(R.id.toggleButton)
        this.mLightSwitch.setOnClickListener {
            this.ditto.store["lights"].findByID(5).update {
                it?.get("isOff")?.set(this.isOff)
            }
        }

//        mLightSwitch.setOnCheckedChangeListener { _, isChecked ->
//            if (isChecked) {
//                // The toggle is enabled
//            } else {
//                // The toggle is disabled
//            }
//        }

        // Create an instance of Ditto
        val androidDependencies = DefaultAndroidDittoDependencies(applicationContext)
        val ditto = Ditto(androidDependencies, DittoIdentity.OfflinePlayground(androidDependencies, "dittomoodlight"))
        ditto.setOfflineOnlyLicenseToken("o2d1c2VyX2lkZURpdHRvZmV4cGlyeXgYMjAyMi0wOC0yNFQwNjo1OTo1OS45OTlaaXNpZ25hdHVyZXhYREVzSCtFeGliMVZ2L0p1WTJGcVJ0UXIrR0p4MDB2dHBKUW4vdzdwa3M1V1VNa2dnTUlPelgvSG1LZXVQWDFaWWhaamFxVElaWjNrczcvNHZlZE90R2c9PQ==")

        this.ditto = ditto
        // This starts Ditto's background synchronization
        this.ditto.tryStartSync()
        this.collection = ditto.store.collection("lights")
        setUpLiveQuery()
        checkPermissions()
    }

    private fun toggleLight(isOff: Boolean) {
        if(isOff) {
            this.mLayout.setBackgroundColor(Color.BLACK)
            this.mButton.setTextColor(Color.BLACK)
            this.mButton.setBackgroundColor(Color.BLACK)
            this.mButton.isClickable = false
            this.mTextView.setTextColor(Color.BLACK)
            this.mLayout.setOnClickListener { null }
//            this.mLightSwitch.isChecked = true

        }
        else {
            this.mLayout.setBackgroundColor(mDefaultColor)
            this.mButton.setTextColor(Color.WHITE)
            this.mButton.setBackgroundColor(Color.BLUE)
            this.mButton.isClickable = true
            this.mTextView.setTextColor(Color.WHITE)
//            this.mLightSwitch.isChecked = false

            this.mLayout.setOnClickListener {
                val color = Color.rgb(nextInt(0, 255), nextInt(0,255), nextInt(0,255))
                val red = Color.red(color)
                val green = Color.green(color)
                val blue = Color.blue(color)

                this.ditto.store["lights"].upsert(
                    mapOf(
                        "_id" to 5,
                        "red" to red,
                        "green" to green,
                        "blue" to blue,
                        "isOff" to false
                    )
                )
            }
        }
        this.isOff = !this.isOff
    }

    private fun setUpLiveQuery() {
        liveQuery = collection.findByID(5).observe { colorDoc, _ ->
            colorDoc?.let {
                val red = colorDoc["red"].floatValue
                val green = colorDoc["green"].floatValue
                val blue = colorDoc["blue"].floatValue
                val isOff = colorDoc["isOff"].booleanValue

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    this.mDefaultColor = Color.rgb(red/255, green/255, blue/255)
                }
//                if(isOff != this.isOff) {
                    toggleLight(isOff)
//                }
//                else {
//                    mLayout.setBackgroundColor(mDefaultColor)
//                }
            }

        }
    }

    private fun checkPermissions() {
        val missing = DittoSyncPermissions(this).missingPermissions()
        if (missing.isNotEmpty()) {
            this.requestPermissions(missing, 0)
        }
    }

    private fun openColorPicker() {
        val ambilWarnaListenerObj = object : AmbilWarnaDialog.OnAmbilWarnaListener {
            override fun onCancel(dialog: AmbilWarnaDialog?) {
                mLayout.setBackgroundColor(mDefaultColor)
            }

            override fun onOk(dialog: AmbilWarnaDialog?, color: Int) {

                val red = Color.red(color)
                val green = Color.green(color)
                val blue = Color.blue(color)

                ditto.store["lights"].upsert(
                    mapOf(
                        "_id" to 5,
                        "red" to red,
                        "green" to green,
                        "blue" to blue,
                        "isOff" to false
                    )
                )
            }
        }

        val colorPicker = AmbilWarnaDialog(this, this.mDefaultColor, ambilWarnaListenerObj)

        colorPicker.show()
    }

}