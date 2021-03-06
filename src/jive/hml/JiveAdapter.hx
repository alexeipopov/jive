package jive.hml;

#if macro
import lime.project.MetaData;
import haxe.rtti.CType.MetaData;
import hml.xml.writer.DefaultNodeWriter;
import hml.xml.writer.IHaxeWriter;
import hml.xml.adapters.base.MergedAdapter;

import hml.base.MatchLevel;
import hml.xml.Data;

import hml.xml.adapters.FlashAdapter;
import hml.xml.adapters.base.BaseMetaAdapter;

import haxe.macro.Expr;

using haxe.macro.Context;
using haxe.macro.Tools;

using StringTools;
using Lambda;
#end

#if macro
class JiveAdapter extends MergedAdapter<XMLData, Node, Type> {
	public function new() {
		super([
		    new JMenuBarNodeAdapter(),
		    new JMenuNodeAdapter(),
		    new AbstractTabbedPaneAdapter(),
			new VectorListModelNodeAdapter(),
			new DefaultMutableTreeNodeAdapter(),
			new ContainerAdapter(),
			new ComponentAdapter(),
			new DisplayObjectAdapter(),
			new IEventDispatcherAdapter(),
			new JiveXMLAdapter(),
            new AssetIconAdapter(),
            new AssetBackgroundAdapter(),
            new BaseCommandAdapter(),
            new DefaultTableColumnModelAdapter(),
            new AbstractTableModelAdapter(),
            new DecorateBorderAdapter(),
            new EmptyLayoutAdapter()
		]);
	}

	static public function register():Void {
		hml.Hml.registerProcessor(new hml.xml.XMLProcessor([new JiveAdapter()]));
	}
}

class ComponentAdapter extends DisplayObjectAdapter {
    public function new(?baseType:ComplexType, ?events:Map<String, MetaData>, ?matchLevel:MatchLevel) {
		if (baseType == null) baseType = macro : org.aswing.Component;
		if (matchLevel == null) matchLevel = CustomLevel(ClassLevel, 20);
		super(baseType, events, matchLevel);
    }

    override public function getNodeWriters():Array<IHaxeNodeWriter<Node>> {
		return [new ComponentWithMetaWriter(baseType, metaWriter, matchLevel)];
	}
}

class ComponentWithMetaWriter extends BaseNodeWithMetaWriter {
	override function writeNodes(node:Node, scope:String, writer:IHaxeWriter<Node>, method:Array<String>) {
		var nodesToRemove = [];
		for (n in node.nodes) {
			if (n.cData != null && n.cData.indexOf('{Binding') >= 0) {
				nodesToRemove.push(n);

				var mode = 'oneway'; //once, oneway, twoway

                var trimmed = n.cData.replace('{Binding','').replace('}','').trim();
				var sourcePropertyName = trimmed;

				// set mode
				if (trimmed.indexOf(" ") >= 0) {
                    var splitted = trimmed.split(" ");
                    sourcePropertyName = splitted[0];
                    if (splitted[1].startsWith("mode=")) {
                    	var m = splitted[1].split("=");
                    	mode = m[1];
                    }
				}

				var valueSource = 'this.dataContext.' + sourcePropertyName;
				var propertyName = scope + "." + n.name.name;

				method.push('if (null != dataContext) { $propertyName = $valueSource; }');

				if (mode.indexOf("way") > 0) {
					method.push('var programmaticalyChange = false;');

					method.push('var sourcePropertyListener = function(_,_) {
						if (!programmaticalyChange) {
							programmaticalyChange = true;
							$propertyName = $valueSource;
							programmaticalyChange = false;
						}
					};');
					method.push('var bindSourceListener = function() { bindx.Bind.bindx($valueSource, sourcePropertyListener); }');
					method.push('if (null != dataContext) { bindSourceListener(); }');
					method.push('bindx.Bind.bindx(this.dataContext, function(old,_) {
							if (null != old) { bindx.Bind.unbindx(old.$sourcePropertyName, sourcePropertyListener);}
							if (null != this.dataContext) {
								$propertyName = $valueSource;
								bindSourceListener();
							}
						});
					');

					if (mode == "twoway") {
						method.push('var propertyListener = function(_,_) {
							if (!programmaticalyChange && null != this.dataContext) {
								programmaticalyChange = true;
								$valueSource = $propertyName;
								programmaticalyChange = false;
							}
						};');
						method.push('bindx.Bind.bindx($propertyName, propertyListener);');
						method.push('bindx.Bind.bindx(this.dataContext, function(old,_) {
						 	if (null != this.dataContext) {
								$valueSource = $propertyName;
							}
						});');
					}
				}
			}
		}
		for (n in nodesToRemove) {
			node.nodes.remove(n);
		}
		super.writeNodes(node, scope, writer, method);
	}
}

class ContainerAdapter extends ComponentAdapter {
    public function new(?baseType:ComplexType, ?events:Map<String, MetaData>, ?matchLevel:MatchLevel) {
		if (baseType == null) baseType = macro : org.aswing.Container;
		if (matchLevel == null) matchLevel = CustomLevel(ClassLevel, 30);
		super(baseType, events, matchLevel);

    }
    override public function getNodeWriters():Array<IHaxeNodeWriter<Node>> {
		return [new ContainerWithMetaWriter(baseType, metaWriter, matchLevel)];
	}
}

class ContainerWithMetaWriter extends ComponentWithMetaWriter {
	override function child(node:Node, scope:String, child:Node, method:Array<String>, assign = false):Void {
		var t = child.superType;
		if (t.indexOf("JPopup") >= 0 || t.indexOf("JWindow") >= 0 || t.indexOf("JFrame") >= 0 || t.indexOf("Dialog") >= 0) {
            method.push('${universalGet(child)}.owner = null;');
        } else if (assign){
            method.push('$scope = ${universalGet(child)};');
        } else {
            method.push('$scope.append(${universalGet(child)});');
        }
	}
}

class AbstractTabbedPaneAdapter extends ComponentAdapter {
    public function new(?baseType:ComplexType, ?events:Map<String, MetaData>, ?matchLevel:MatchLevel) {
		if (baseType == null) baseType = macro : org.aswing.AbstractTabbedPane;
		if (matchLevel == null) matchLevel = CustomLevel(ClassLevel, 40);
		super(baseType, events, matchLevel);

    }
    override public function getNodeWriters():Array<IHaxeNodeWriter<Node>> {
		return [new AbstractTabbedPaneWithMetaWriter(baseType, metaWriter, matchLevel)];
	}
}

class AbstractTabbedPaneWithMetaWriter extends ComponentWithMetaWriter {
	override function child(node:Node, scope:String, child:Node, method:Array<String>, assign = false):Void {
		method.push('$scope.appendTabInfo(${universalGet(child)});');
	}
}

class DefaultMutableTreeNodeAdapter extends ComponentAdapter {
    public function new(?baseType:ComplexType, ?events:Map<String, MetaData>, ?matchLevel:MatchLevel) {
		if (baseType == null) baseType = macro : org.aswing.tree.DefaultMutableTreeNode;
		if (matchLevel == null) matchLevel = CustomLevel(ClassLevel, 10);
		super(baseType, events, matchLevel);

    }
    override public function getNodeWriters():Array<IHaxeNodeWriter<Node>> {
		return [new DefaultMutableTreeNodeWithMetaWriter(baseType, metaWriter, matchLevel)];
	}
}

class DefaultMutableTreeNodeWithMetaWriter extends ComponentWithMetaWriter {
	override function child(node:Node, scope:String, child:Node, method:Array<String>, assign = false):Void {
		method.push('$scope.append(${universalGet(child)});');
	}
}

class VectorListModelNodeAdapter extends ComponentAdapter {
    public function new(?baseType:ComplexType, ?events:Map<String, MetaData>, ?matchLevel:MatchLevel) {
		if (baseType == null) baseType = macro : org.aswing.VectorListModel;
		if (matchLevel == null) matchLevel = CustomLevel(ClassLevel, 10);
		super(baseType, events, matchLevel);

    }
    override public function getNodeWriters():Array<IHaxeNodeWriter<Node>> {
		return [new VectorListModelNodeWithMetaWriter(baseType, metaWriter, matchLevel)];
	}
}

class VectorListModelNodeWithMetaWriter extends ComponentWithMetaWriter {
	override function child(node:Node, scope:String, child:Node, method:Array<String>, assign = false):Void {
		method.push('$scope.append(${universalGet(child)});');
	}
}

class JMenuBarNodeAdapter extends ComponentAdapter {
    public function new(?baseType:ComplexType, ?events:Map<String, MetaData>, ?matchLevel:MatchLevel) {
		if (baseType == null) baseType = macro : org.aswing.JMenuBar;
		if (matchLevel == null) matchLevel = CustomLevel(ClassLevel, 40);
		super(baseType, events, matchLevel);

    }
    override public function getNodeWriters():Array<IHaxeNodeWriter<Node>> {
		return [new JMenuBarNodeWithMetaWriter(baseType, metaWriter, matchLevel)];
	}
}

class JMenuBarNodeWithMetaWriter extends ComponentWithMetaWriter {
	override function child(node:Node, scope:String, child:Node, method:Array<String>, assign = false):Void {
		method.push('$scope.addMenu(${universalGet(child)});');
	}
}

class JMenuNodeAdapter extends ComponentAdapter {
    public function new(?baseType:ComplexType, ?events:Map<String, MetaData>, ?matchLevel:MatchLevel) {
		if (baseType == null) baseType = macro : org.aswing.JMenu;
		if (matchLevel == null) matchLevel = CustomLevel(ClassLevel, 60);
		super(baseType, events, matchLevel);

    }
    override public function getNodeWriters():Array<IHaxeNodeWriter<Node>> {
		return [new JMenuNodeWithMetaWriter(baseType, metaWriter, matchLevel)];
	}
}

class JMenuNodeWithMetaWriter extends ComponentWithMetaWriter {
	override function child(node:Node, scope:String, child:Node, method:Array<String>, assign = false):Void {
		method.push('$scope.append(${universalGet(child)});');
	}
}

class AssetIconAdapter extends ComponentAdapter {
    public function new(?baseType:ComplexType, ?events:Map<String, MetaData>, ?matchLevel:MatchLevel) {
        if (baseType == null) baseType = macro : org.aswing.AssetIcon;
        if (matchLevel == null) matchLevel = CustomLevel(ClassLevel, 10);
        super(baseType, events, matchLevel);

    }
}

class AssetBackgroundAdapter extends ComponentAdapter {
    public function new(?baseType:ComplexType, ?events:Map<String, MetaData>, ?matchLevel:MatchLevel) {
        if (baseType == null) baseType = macro : org.aswing.AssetBackground;
        if (matchLevel == null) matchLevel = CustomLevel(ClassLevel, 10);
        super(baseType, events, matchLevel);

    }
}

class DecorateBorderAdapter extends ComponentAdapter {
    public function new(?baseType:ComplexType, ?events:Map<String, MetaData>, ?matchLevel:MatchLevel) {
        if (baseType == null) baseType = macro : org.aswing.border.DecorateBorder;
        if (matchLevel == null) matchLevel = CustomLevel(ClassLevel, 10);
        super(baseType, events, matchLevel);

    }
}

class BaseCommandAdapter extends ComponentAdapter {
    public function new(?baseType:ComplexType, ?events:Map<String, MetaData>, ?matchLevel:MatchLevel) {
        if (baseType == null) baseType = macro : jive.BaseCommand;
        if (matchLevel == null) matchLevel = CustomLevel(ClassLevel, 10);
        super(baseType, events, matchLevel);

    }
}

class EmptyLayoutAdapter extends ComponentAdapter {
    public function new(?baseType:ComplexType, ?events:Map<String, MetaData>, ?matchLevel:MatchLevel) {
        if (baseType == null) baseType = macro : org.aswing.EmptyLayout;
        if (matchLevel == null) matchLevel = CustomLevel(ClassLevel, 10);
        super(baseType, events, matchLevel);

    }
}

class AbstractTableModelAdapter extends ComponentAdapter {
    public function new(?baseType:ComplexType, ?events:Map<String, MetaData>, ?matchLevel:MatchLevel) {
        if (baseType == null) baseType = macro : org.aswing.table.AbstractTableModel;
        if (matchLevel == null) matchLevel = CustomLevel(ClassLevel, 10);
        super(baseType, events, matchLevel);

    }
}


class DefaultTableColumnModelAdapter extends ComponentAdapter {
    public function new(?baseType:ComplexType, ?events:Map<String, MetaData>, ?matchLevel:MatchLevel) {
        if (baseType == null) baseType = macro : org.aswing.table.DefaultTableColumnModel;
        if (matchLevel == null) matchLevel = CustomLevel(ClassLevel, 10);
        super(baseType, events, matchLevel);

    }
    override public function getNodeWriters():Array<IHaxeNodeWriter<Node>> {
        return [new DefaultTableColumnModelNodeWithMetaWriter(baseType, metaWriter, matchLevel)];
    }
}

class DefaultTableColumnModelNodeWithMetaWriter extends ComponentWithMetaWriter {
    override function child(node:Node, scope:String, child:Node, method:Array<String>, assign = false):Void {
        method.push('$scope.addColumn(${universalGet(child)});');
    }
}
#end