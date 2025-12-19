# LollipopPlot
Creates an interactive lollipop chart from a table. Each x-position (row) shows two markers (Top and Second) connected by a vertical line whose color indicates which marker has the larger value. The chart provides an interactive legend: clicking a legend item toggles that series' visibility and updates connector colors (colored when both series visible, faded otherwise). The function returns the chart object so you can modify appearance or query handles programmatically.

Function Signature

obj = lollipopplot(T, varargin)
Inputs

T — MATLAB table (required). Each row is a data point (an x position).
Name-value pairs (optional):
'TeamVar' — column name or index for x-axis labels (categorical/string). Default: first text-like column.
'TopNameVar' — column name/index for top-marker label. Default: first text-like after TeamVar.
'SecondNameVar' — column name/index for second-marker label. Default: second text-like after TeamVar.
'TopValueVar' — column name/index for top numeric values. Default: one of the numeric columns (most significant).
'SecondValueVar' — column name/index for second numeric values. Default: another numeric column (second-most significant).
Output

obj — instance of InteractiveLollipopChart containing handles and properties:
obj.Fig, obj.Ax — figure and axes handles.
obj.ScatterTop, obj.ScatterSecond — scatter handles for top and second markers.
obj.Lines — array of line handles (one per pair).
obj.TopColor, obj.SecondColor, obj.FadedColor — color properties you can change.
Behavior Summary
Draws one connector line per row: line YData = [yTop ySecond]. Line color is obj.TopColor if yTop ≥ ySecond, otherwise obj.SecondColor.
Draws two scatter series (large markers) with black edges and text labels inside markers.
Adds data tip rows for readable tooltips.
Adds a legend with ItemHitFcn that toggles series visibility and:
If both series visible: connector lines are colored by higher endpoint.
If one or both series hidden: connector lines set to obj.FadedColor.
Default colors and visual parameters are set in the constructor but are public properties you can adjust after construction.
Minimal Usage Examples
Create chart with automatic column detection:


obj.TopColor    = [0 0.5 0.8];
obj.SecondColor = [0.85 0.3 0.1];
obj.FadedColor  = [0.9 0.9 0.9];

% Redraw lines based on new colors:
for k = 1:numel(obj.Lines)
    y = obj.Lines(k).YData;
    if y(1) >= y(2)
        obj.Lines(k).Color = obj.TopColor;
    else
        obj.Lines(k).Color = obj.SecondColor;
    end
end

Toggle visibility programmatically (same effect as legend click):


obj.ScatterTop.Visible = 'off';
obj.ScatterSecond.Visible = 'on';
% then update connector colors as above or call the class method if exposed
Customization Points
Marker size, line width, fonts, data-tip rows, label offsets are defined in drawChart and may be adjusted there or by editing properties if you expose them.
If you want per-marker colors (Nx3 CData), extend obj.TopColor / obj.SecondColor to store CData and adapt legend click logic to select representative color or vectorized update.
For dark backgrounds, set obj.Ax.XColor/YColor and text colors to light values.
Implementation Notes and Guarantees
The factory wrapper lollipopplot calls InteractiveLollipopChart and returns the object; existing code using createLollipopChart can be kept as an alias.
The class stores color values as properties to avoid scope errors (Unrecognized function or variable 'topColor' / 'secondColor').
Connector lines use YData = [yTop ySecond] so comparison uses ydata(1) versus ydata(2).
Legend interactivity uses the Legend ItemHitFcn callback; the callback toggles visibility and updates connector colors and marker alpha for visual feedback.
