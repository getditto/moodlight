package live.ditto.moodlight

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.content.ContextCompat
import live.ditto.*
import live.ditto.android.DefaultAndroidDittoDependencies
import yuku.ambilwarna.AmbilWarnaDialog
import kotlin.properties.Delegates
import kotlin.random.Random.Default.nextInt

class MainActivity : AppCompatActivity() {
    lateinit var mLayout: ConstraintLayout
    var mDefaultColor by Delegates.notNull<Int>()
    private lateinit var mButton: Button
    private lateinit var mTextView: TextView
    private lateinit var ditto: Ditto
    private lateinit var collection: DittoCollection
    private lateinit var liveQuery: DittoLiveQuery

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        this.mLayout = findViewById(R.id.layout)
        this.mDefaultColor = ContextCompat.getColor(this, R.color.purple_200)
        this.mLayout.setBackgroundColor(mDefaultColor)
        this.mTextView = findViewById(R.id.textview)
        this.mTextView.setTextColor(Color.WHITE)
        this.mTextView.textSize = 22.0F
        this.mTextView.gravity = Gravity.CENTER_VERTICAL or Gravity.CENTER_HORIZONTAL
        this.mButton = findViewById(R.id.button)
        this.mButton.setOnClickListener { openColorPicker(); }

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
                    "disabled" to false
                )
            )
        }
        // Create an instance of Ditto
        val androidDependencies = DefaultAndroidDittoDependencies(applicationContext)
        val ditto = Ditto(androidDependencies, DittoIdentity.OfflinePlayground(androidDependencies, "dittomoodlight"))
        ditto.setOfflineOnlyLicenseToken("o2d1c2VyX2lkZURpdHRvZmV4cGlyeXgYMjAyMi0wOC0yNFQwNjo1OTo1OS45OTlaaXNpZ25hdHVyZXhYREVzSCtFeGliMVZ2L0p1WTJGcVJ0UXIrR0p4MDB2dHBKUW4vdzdwa3M1V1VNa2dnTUlPelgvSG1LZXVQWDFaWWhaamFxVElaWjNrczcvNHZlZE90R2c9PQ==")

        this.ditto = ditto
        // This starts Ditto's background synchronization
        this.ditto.tryStartSync()
        this.collection = ditto.store.collection("lights")
        setUpLiveQuery()
    }

    private fun setUpLiveQuery() {
        liveQuery = collection.findByID(DittoDocumentID(5)).observe { colorDoc, _ ->
            colorDoc?.let {
                val red = colorDoc["red"].floatValue
                val green = colorDoc["green"].floatValue
                val blue = colorDoc["blue"].floatValue

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    this.mDefaultColor = Color.rgb(red/255, green/255, blue/255)
                }
            }
            mLayout.setBackgroundColor(mDefaultColor)
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
                        "disabled" to false
                    )
                )
            }
        }

        val colorPicker = AmbilWarnaDialog(this, this.mDefaultColor, ambilWarnaListenerObj)

        colorPicker.show()
    }

}