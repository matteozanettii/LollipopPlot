classdef LollipopManager < handle
    properties
        Tbl
        XVar
        YVars
        Fig
        Ax
        Stems
        DumbbellLines
        DumbbellMarkers
        Legend
        MarkerSize = 80
        Colors = []
        OffsetFrac = 0.02
        ShowDelta = true
        Baseline = 0
    end

    methods
        function obj = LollipopManager(tbl, xVar, yVars, opts)
            % Validate table
            if ~istable(tbl)
                error('LollipopManager:BadInput', 'First argument must be a table.');
            end
            obj.Tbl = tbl;

            % Normalize XVar to char scalar
            if isstring(xVar)
                xVar = char(xVar);
            end
            if ~(ischar(xVar) || isstring(xVar))
                error('LollipopManager:BadXVar', 'XVar must be a variable name (char or string).');
            end
            obj.XVar = char(xVar);

            % Normalize YVars to cellstr
            if isempty(yVars)
                obj.YVars = {};
            elseif iscell(yVars)
                obj.YVars = cellfun(@char, yVars, 'UniformOutput', false);
            elseif isstring(yVars)
                obj.YVars = cellstr(yVars);
            elseif ischar(yVars)
                obj.YVars = {char(yVars)};
            else
                error('LollipopManager:BadYVars', 'YVars must be char, string, or cell of names.');
            end

            % Forward optional options
            if nargin >= 4 && isstruct(opts)
                if isfield(opts,'MarkerSize'), obj.MarkerSize = opts.MarkerSize; end
                if isfield(opts,'Colors'), obj.Colors = opts.Colors; end
                if isfield(opts,'OffsetFrac'), obj.OffsetFrac = opts.OffsetFrac; end
                if isfield(opts,'ShowDelta'), obj.ShowDelta = opts.ShowDelta; end
                if isfield(opts,'Baseline'), obj.Baseline = opts.Baseline; end
            end
        end

        function draw(obj)
            % Validate XVar exists
            if ~isvarname(obj.XVar) || ~ismember(obj.XVar, obj.Tbl.Properties.VariableNames)
                error('LollipopManager:MissingXVar', 'XVar ''%s'' not found in table.', obj.XVar);
            end
            x = obj.Tbl.(obj.XVar);

            nY = numel(obj.YVars);

            % prepare colors
            if isempty(obj.Colors)
                cols = lines(max(2,nY));
            else
                cols = obj.Colors;
                if size(cols,1) < max(2,nY)
                    cols = repmat(cols(1,:), max(2,nY), 1);
                end
            end

            obj.Fig = figure('Name','Lollipop / Dumbbell Plot');
            obj.Ax = axes('Parent',obj.Fig); hold(obj.Ax,'on');

            % Dumbbell vertical when exactly two Y variables
            if nY == 2
                % Ensure variables exist
                name1 = char(obj.YVars{1});
                name2 = char(obj.YVars{2});
                if ~ismember(name1, obj.Tbl.Properties.VariableNames) || ~ismember(name2, obj.Tbl.Properties.VariableNames)
                    error('LollipopManager:MissingYVar', 'One or more YVars not found in table.');
                end

                y1 = obj.Tbl.(name1);
                y2 = obj.Tbl.(name2);
                xnum = obj.convertXforPlot(x);
                N = numel(xnum);

                % compute offset
                xr = max(xnum)-min(xnum);
                if xr == 0, xr = 1; end
                off = obj.OffsetFrac * xr;

                obj.DumbbellLines = gobjects(N,1);
                obj.DumbbellMarkers = gobjects(2,N);
                for i = 1:N
                    v1 = y1(i); v2 = y2(i);
                    % draw vertical line between min and max (true dumbbell)
                    ysorted = sort([v1 v2]);
                    obj.DumbbellLines(i) = line(obj.Ax, [xnum(i) xnum(i)], ysorted, ...
                        'Color',[0.5 0.5 0.5], 'LineWidth', 1.5, 'HandleVisibility','off', 'Clipping','off');
                    % markers with slight horizontal offset to avoid overlap
                    obj.DumbbellMarkers(1,i) = scatter(obj.Ax, xnum(i)-off, v1, obj.MarkerSize, cols(1,:), 'filled', ...
                        'DisplayName', name1);
                    obj.DumbbellMarkers(2,i) = scatter(obj.Ax, xnum(i)+off, v2, obj.MarkerSize, cols(2,:), 'filled', ...
                        'DisplayName', name2);
                    % optional delta label (midpoint)
                    if obj.ShowDelta
                        midy = (v1+v2)/2;
                        dval = v2 - v1;
                        txt = sprintf('%+.2g', dval);
                        text(obj.Ax, xnum(i)+0.02*xr, midy, txt, 'HorizontalAlignment','left', 'FontSize',9);
                    end
                end

                % set ticks/labels for categorical/datetime if needed
                obj.applyXTickLabelsIfNeeded(x, xnum);

                % legend and interactivity
                hRep = [obj.DumbbellMarkers(1,1), obj.DumbbellMarkers(2,1)];
                obj.Legend = legend(obj.Ax, hRep, 'AutoUpdate','off', 'Location','best');
                obj.Legend.ItemHitFcn = @(lgd,event)obj.onLegendClick(event);

                xlabel(obj.Ax, obj.XVar);
                ylabel(obj.Ax, 'Value');
                title(obj.Ax, 'Lollipop Plot ');
                grid(obj.Ax,'on');

            else
                % fallback: lollipop/stem for 1 or >2 series
                n = nY;
                if isempty(obj.Colors), cols = lines(n); end
                obj.Stems = gobjects(1,n);
                xnum = obj.convertXforPlot(x);
                for k = 1:n
                    namek = char(obj.YVars{k});
                    if ~ismember(namek, obj.Tbl.Properties.VariableNames)
                        error('LollipopManager:MissingYVar', 'YVar ''%s'' not found in table.', namek);
                    end
                    y = obj.Tbl.(namek);
                    h = stem(obj.Ax, xnum, y, 'filled', 'LineWidth',1.5);
                    h.BaseValue = obj.Baseline;
                    h.Color = cols(k,:);
                    h.MarkerFaceColor = cols(k,:);
                    h.DisplayName = namek;
                    try set(h.MarkerHandle,'SizeData',obj.MarkerSize); end
                    obj.Stems(k) = h;
                end
                obj.applyXTickLabelsIfNeeded(x, xnum);
                obj.Legend = legend(obj.Ax, obj.Stems, 'AutoUpdate','off', 'Location','best');
                obj.Legend.ItemHitFcn = @(lgd,event)obj.onLegendClick(event);
                xlabel(obj.Ax, obj.XVar);
                ylabel(obj.Ax, 'Value');
                title(obj.Ax, 'Lollipop Plot (vertical)');
                grid(obj.Ax,'on');
            end

            hold(obj.Ax,'off');
        end

        function onLegendClick(obj, event)
            peer = event.Peer;
            if isempty(peer) || ~isgraphics(peer), return; end

            if numel(obj.YVars) == 2 && ~isempty(obj.DumbbellMarkers)
                % identify which series toggled (compare DisplayName)
                name = peer.DisplayName;
                name1 = char(obj.YVars{1});
                name2 = char(obj.YVars{2});
                if strcmp(name, name1), idx = 1;
                else idx = 2; end

                % toggle visibility for that series markers
                isOn = strcmp(obj.DumbbellMarkers(idx,1).Visible,'on');
                newVis = tern(isOn,'off','on');
                set(obj.DumbbellMarkers(idx,:), 'Visible', newVis);

                % adjust lines: if both endpoints hidden -> hide lines; if one hidden -> dim lines
                vis1 = any(strcmp({obj.DumbbellMarkers(1,:).Visible},'on'));
                vis2 = any(strcmp({obj.DumbbellMarkers(2,:).Visible},'on'));
                if vis1 && vis2
                    set(obj.DumbbellLines, 'Visible','on', 'Color',[0.5 0.5 0.5], 'LineWidth',1.5);
                elseif ~vis1 && ~vis2
                    set(obj.DumbbellLines, 'Visible','off');
                else
                    set(obj.DumbbellLines, 'Visible','on', 'Color',[0.8 0.8 0.8], 'LineWidth',1);
                end
                obj.updateLegendStringsDumbbell();
            else
                % stems/lollipop: toggle peer visibility
                if isprop(peer,'Visible')
                    peer.Visible = tern(strcmp(peer.Visible,'on'),'off','on');
                end
                obj.updateLegendStringsStems(peer);
            end
        end

        function updateLegendStringsDumbbell(obj)
            strs = cell(1,2);
            for k = 1:2
                visAny = any(strcmp({obj.DumbbellMarkers(k,:).Visible},'on'));
                if visAny, strs{k} = char(obj.YVars{k}); else strs{k} = ['(off) ' char(obj.YVars{k})]; end
            end
            obj.Legend.String = strs;
        end

        function updateLegendStringsStems(obj, peer)
            names = obj.Legend.String;
            if ischar(names), names = {names}; end
            idx = find(obj.Stems == peer,1);
            if isempty(idx), return; end
            if any(startsWith(names{idx},'(off) ')), names{idx} = char(obj.YVars{idx});
            else names{idx} = ['(off) ' char(obj.YVars{idx})]; end
            obj.Legend.String = names;
        end

        function xnum = convertXforPlot(~, x)
            % convert categorical/string/datetime to numeric positions, preserve numeric otherwise
            if iscategorical(x) || isstring(x) || iscellstr(x)
                xnum = (1:numel(x))';
            elseif isdatetime(x)
                xnum = datenum(x);
            else
                xnum = x;
            end
        end

        function applyXTickLabelsIfNeeded(obj, xOrig, xnum)
            if iscategorical(xOrig) || isstring(xOrig) || iscellstr(xOrig)
                cats = unique(xOrig,'stable');
                obj.Ax.XTick = 1:numel(cats);
                obj.Ax.XTickLabel = cellstr(string(cats));
            elseif isdatetime(xOrig)
                datetick(obj.Ax,'x','keepticks');
            else
                % numeric - leave ticks automatic
            end
        end
    end
end

% small helper ternary
function out = tern(cond,a,b)
if cond, out = a; else out = b; end
end
