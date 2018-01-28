/**
 * ##copyright##
 * See LICENSE.md
 *
 * @author    Maxime Damecour (http://nnvtn.ca)
 * @version   0.4
 * @since     2015-01-22
 */
import java.util.Collections;
import java.util.Arrays;


/**
 * Manage the drawing buffer.
 * Perhaps subclass features such as OSC, dedicated mouse device, slave mode...
 */
abstract class CanvasManager implements FreelinerConfig {
    // Template renderer needed to do the rendering
    TemplateRenderer templateRenderer;
    public PGraphics guiCanvas;
    CommandProcessor commandProcessor;
    // applet needed for syhpon/spout layers
    PApplet applet;
    // shaders need to know whats up with time.
    Synchroniser sync;
    // boolean makeMaskFlag = false;

    //  abstract methods
    abstract void render(ArrayList<RenderableTemplate> _toRender);
    abstract PGraphics getCanvas();
    abstract void setup();
    // concrete methods?
    public boolean layerCreator(String[] _args) {
        return false;
    }

    public int setTrails(int _t, int _max) {
        return 0;
    }

    // implemented methods
    public void inject(TemplateRenderer _tr) {
        templateRenderer = _tr;
    }
    public void inject(CommandProcessor _cp) {
        commandProcessor = _cp;
    }
    public void inject(Synchroniser _s) {
        sync = _s;
    }
    // no commands available
    public boolean parseCMD(String[] _args) {
        return false;
    }
    public String getLayerInfo() {
        return "none";
    }
}

/**
 * Simple CanvasManager subclass.
 * Lightest possible for faster performance on older hardware
 * AKA classic mode.
 */
class ClassicCanvasManager extends CanvasManager {
    TracerLayer tracerLayer;
    RenderLayer renderLayer;

    public ClassicCanvasManager(PApplet _applet, PGraphics _gui) {
        applet = _applet;
        guiCanvas = _gui;
    }

    public void setup() {
        tracerLayer = new TracerLayer();
        renderLayer = new RenderLayer();
    }

    public void render(ArrayList<RenderableTemplate> _toRender) {
        tracerLayer.beginDrawing();
        for(RenderableTemplate _rt : _toRender){
            if(_rt.getRenderLayer() == 0) templateRenderer.render(_rt, tracerLayer.getCanvas());
        }
        tracerLayer.endDrawing();

        renderLayer.beginDrawing();
        for(RenderableTemplate _rt : _toRender){
            if(_rt.getRenderLayer() != 0) templateRenderer.render(_rt, renderLayer.getCanvas());
        }
        renderLayer.endDrawing();

        image(tracerLayer.getCanvas(),0,0);
        image(renderLayer.getCanvas(),0,0);
        image(guiCanvas,0,0);
    }

    // unfortunatly for LEDs wont get the shader effects...
    public PGraphics getCanvas() {
        return tracerLayer.getCanvas();
    }

    public int setTrails(int _t, int _max) {
        return tracerLayer.setTrails(_t, _max);
    }
}

/**
 * Customizable rendering layer system
 * AKA custom deluxe
 */
class LayeredCanvasManager extends CanvasManager {
    // all of the layers?
    ArrayList<Layer> layers;
    // layers that can be drawn on
    ArrayList<RenderLayer> renderLayers;
    // MergeLayer mergeLayer;
    PGraphics mergeCanvas;

    public LayeredCanvasManager(PApplet _pa, PGraphics _gui) {
        applet = _pa;
        guiCanvas = _gui;
        layers = new ArrayList();
        renderLayers = new ArrayList();
        // mergeLayer = new MergeLayer();
        mergeCanvas = createGraphics(width, height, P2D);

    }

    public void setup() {
        // define the stack
        layerCreator("layer tracerOne tracerLayer");
        layerCreator("layer firstShader shaderLayer");
        // layerCreator("layer squareMask maskLayer");
        layerCreator("layer mergeA mergeLayer");
        ////////////////////////////////////////////////////
        layerCreator("layer untraced renderLayer");
        // layerCreator("layer squareMask maskLayer");
        layerCreator("layer secondShader shaderLayer");
        // layerCreator("layer outMask maskLayer");
        layerCreator("layer mergeB mergeLayer");

        layerCreator("layer untraced2 renderLayer");
        layerCreator("layer thirdShader shaderLayer");
        // layerCreator("layer squareMask maskLayer");
        layerCreator("layer mergeC mergeLayer");
        ////////////////////////////////////////////////////
        ////////////////////////////////////////////////////
        // layerCreator("layer cap captureLayer");
        // layerCreator("layer capMask maskLayer");
        // layerCreator("layer mergeC mergeLayer");
        ////////////////////////////////////////////////////

        layerCreator("layer mergeOutput mergeOutput");
        layerCreator("layer fourthShader shaderLayer");
        layerCreator("layer masker maskLayer");

        // led/dmx layer
        layerCreator("layer fix fixtureLayer");
        // layerCreator("layer cap captureLayer");
        layerCreator("layer gui guiLayer");
        // add frame sharing layers by default, they get deleted if they are not enabled.
        layerCreator("layer syphon syphonLayer");
        layerCreator("layer spout spoutLayer");

        // layerCreator("layer screenshot screenshotLayer");
        layerCreator("layer screen outputLayer");

        // printLayers();
    }

    public int setTrails(int _t, int _max) {
        int _ret = 0;
        for(Layer _lyr : layers)
            if(_lyr instanceof TracerLayer)
                _ret = ((TracerLayer)_lyr).setTrails(_t, _max);
        return _ret;
    }

    public Layer addLayer(Layer _lr) {
        if(_lr == null) return null;
        layers.add(_lr);
        //if(_lr instanceof VertexShaderLayer)
        //  renderLayers.add((RenderLayer)_lr);
        //else
        if(_lr instanceof RenderLayer && !(_lr instanceof ShaderLayer))
            renderLayers.add((RenderLayer)_lr);
        return _lr;
    }

    public boolean layerCreator(String _s) {
        return layerCreator(split(_s, ' '));
    }

    // takes a cmd : layer newID type : layer myTracer tracerLayer
    public boolean layerCreator(String[] _args) {
        if(_args.length < 3) return false;
        // first check if there is a layer with the same Name or other subclass
        Layer _existingLayer = null;
        for(Layer _l : layers) {
            if(_l.getID().equals(_args[1])) {
                _existingLayer = _l;
                _args[2] = "containerLayer";
                _args[1] = getNewCloneName(_args[1]);
            }
        }

        Layer _lyr = null;

        switch(_args[2]) {
        case "renderLayer":
            _lyr = new RenderLayer();
            break;
        case "tracerLayer":
            _lyr = new TracerLayer();
            break;
        case "mergeLayer":
            _lyr = new MergeLayer();
            _lyr.setCanvas(mergeCanvas);
            break;
        case "mergeOutput":
            _lyr = new MergeOutput();
            _lyr.setCanvas(mergeCanvas);
            break;
        case "outputLayer":
            _lyr = new OutputLayer();
            break;
        case "maskLayer":
            _lyr = new MaskLayer();
            break;
        case "shaderLayer":
            _lyr = new ShaderLayer(sync);
            break;
        // case "vertexShaderLayer":
        //   _lyr = new VertexShaderLayer();
        //   break;
        case "imageLayer":
            _lyr = new ImageLayer();
            break;
        case "guiLayer":
            _lyr = new GuiLayer(guiCanvas);
            break;
        case "spoutLayer":
            _lyr = addSpoutLayer();
            break;
        case "syphonLayer":
            _lyr = addSyphonLayer();
            break;
        case "fixtureLayer":
            _lyr = new FixtureLayer(applet);
            break;
        case "captureLayer":
            _lyr = new CaptureLayer(applet);
            break;
        case "screenshotLayer":
            _lyr = new ScreenshotLayer();
            break;
        case "containerLayer":
            if(_existingLayer != null) {
                _lyr = new ContainerLayer();
                _lyr.setLayer(_existingLayer);
            }
            break;
        }
        if(_lyr != null) {
            _lyr.setID(_args[1]);
            addLayer(_lyr);
            return true;
        }
        return false;
    }

    private Layer addSyphonLayer() {
        Layer _lyr = new SyphonLayer(applet);
        if(_lyr.useLayer()) return _lyr;
        else return null;
    }

    private Layer addSpoutLayer() {
        Layer _lyr = new SpoutLayer(applet);
        if(_lyr.useLayer()) return _lyr;
        else return null;
    }

    /**
     * makes a different name for a same layer so the layer can be tapped at different places.
     */
    private String getNewCloneName(String _s) {
        for(Layer _l : layers) {
            if(_l.getID().equals(_s))
                return getNewCloneName(_s+"I");
        }
        return _s;
    }

    /**
     * Begin redering process. Make sure to end it with endRender();
     */
    public void render(ArrayList<RenderableTemplate> _toRender) {
        int _index = 0;
        for(Layer _rl : renderLayers) {
            _rl.beginDrawing();
            for(RenderableTemplate _rt : _toRender) {
                if(_rt.getRenderLayer() == _index) templateRenderer.render(_rt, _rl.getCanvas());
            }
            _rl.endDrawing();
            _index++;

        }

        mergeCanvas.beginDraw();
        mergeCanvas.clear();

        // and this is where the magic happens
        PGraphics _prev = null;
        for(Layer _lr : layers) _prev = _lr.apply(_prev);
        // thats it

        // check for cmds and mask making.
        for(Layer _lr : layers) {
            if(_lr instanceof MaskLayer) {
                if(((MaskLayer)_lr).checkMakeMask()) ((MaskLayer)_lr).makeMask(mergeCanvas);
            }
            if(_lr.hasCMD()) {
                commandProcessor.queueCMD(_lr.getCMD());
            }
        }
    }

    public final PGraphics getCanvas() {
        return mergeCanvas;// mergeLayer.getCanvas();
    }

    ////////////////////////////////////////////////////////////////////////////////////
    ///////
    ///////    Actions
    ///////
    ////////////////////////////////////////////////////////////////////////////////////

    public void updateOptions() {
        ArrayList<String> _shaders = freeliner.getFilesFrom(PATH_TO_SHADERS, ".glsl");
        ArrayList<String> _fixtures = freeliner.getFilesFrom(PATH_TO_FIXTURES, ".xml");
        ArrayList<String> _images = freeliner.getFilesFrom(PATH_TO_IMAGES, ".png");
        _images.addAll(freeliner.getFilesFrom(PATH_TO_IMAGES, ".png"));
        for(Layer _lyr : layers) {
            if(_lyr instanceof ImageLayer) _lyr.setOptions(sortAndArray(_images));
            else if(_lyr instanceof ShaderLayer) _lyr.setOptions(sortAndArray(_shaders));
            else if(_lyr instanceof FixtureLayer) _lyr.setOptions(sortAndArray(_fixtures));
        }
    }

    private String[] sortAndArray(ArrayList<String> _in){
        String[] _out = _in.toArray(new String[_in.size()]);
        Arrays.sort(_out);
        return _out;
    }

    public void printLayers() {
        println("+--------Layers--------+");
        for(Layer _lr : layers) println(_lr.getID());
        println("+--------details--------+");
        for(Layer _lr : layers) printLayer(_lr);
        println("+--------END-----------+");
    }

    // type-layerName
    // the rest can be figured out in JS
    public String getLayerInfo() {
        updateOptions();
        String _out = "";
        for(Layer _lyr : layers) {
            _out += _lyr.getID()+"-";
            _out += _lyr.getName()+"-";
            if(_lyr.useLayer()) _out += str(1)+"-";
            else _out += str(0)+"-";
            _out += _lyr.getSelectedOption()+"-";
            for(String _s : _lyr.getOptions()) _out += _s+"-";
            // _out += ((_lyr instanceof ShaderLayer) ? 1 : 0 )+"-";
            _out += " ";
        }
        return _out;
    }

    public void printLayer(Layer _lyr) {
        println(".............."+_lyr.getID()+"..............");
        println(_lyr.getDescription());
        for(String _cmd : _lyr.getCMDList() ) println(_cmd);
        println("enable "+_lyr.useLayer());
        println("............................................");
    }

    public void screenShot() {
        // save screenshot to capture/screenshots/datetime.png
    }

    ////////////////////////////////////////////////////////////////////////////////////
    ///////
    ///////    Modifiers
    ///////
    ////////////////////////////////////////////////////////////////////////////////////

    public boolean parseCMD(String[] _args) {
        if(_args.length < 3) return false;
        else if(_args[2].equals("swap") ) {
            swapOrder(_args[1], stringInt(_args[3]));
            return true;
        } else if(_args[2].equals("delete") ) {
            return deleteLayer(getLayer(_args[1]));
        }

        Layer _lyr = getLayer(_args[1]);
        if(_lyr == null) return layerCreator(_args);
        else if(_lyr.parseCMD(_args)) return true;
        else return layerCreator(_args);
    }

    public Layer getLayer(String _id) {
        for(Layer _lyr : layers)
            if(_lyr.getID().equals(_id)) return _lyr;
        return null;
    }

    // seem to work!
    public void swapOrder(String _id, int _dir) {
        for(int i = 0; i < layers.size(); i++) {
            if(layers.get(i).getID().equals(_id)) {
                if(i + _dir >= 0 && i + _dir < layers.size()) {
                    Collections.swap(layers, i, i + _dir);
                    return;
                }
            }
        }
    }

    public boolean deleteLayer(Layer _lyr) {
        if(_lyr != null) layers.remove(_lyr);
        else return false;
        return true;
    }

    public void addLayer(String _id) {
        addLayer(new Layer()).setID(_id);
    }

    /**
     * Toggle the use of background with alpha value
     * @return boolean value given
     */
    public boolean toggleTrails() {
        //tracerLayer.toggleLayer();
        return false;//tracerLayer.useLayer();
    }
}
