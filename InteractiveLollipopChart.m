classdef InteractiveLollipopChart < handle
    % InteractiveLollipopChart  Improved lollipop chart with vectorized graphics
    %
    % Usage:
    %   obj = InteractiveLollipopChart(T)
    %   obj = InteractiveLollipopChart(T, 'TopValueVar', 'ColA', 'SecondValueVar', 'ColB', ...)
    %
    % Behavior:
    % - X axis shows the selected value column names (TopValueVar and SecondValueVar).
    % - Each row of T generates a vertical connector between the two x positions.
    % - Point labels are taken from T.Properties.RowNames (fallback to row indices).
    % - Vectorized creation of lines/text and two scatter series for performance.
    %
    % Save as InteractiveLollipopChart.m

    properties (SetAccess = private)
        T table
        TeamVar
        TopNameVar
        TopValueVar
        SecondNameVar
        SecondValueVar

        Fig
        Ax
        ScatterTop
        ScatterSecond
        Lines   % array of Line handles

        TopColor
        SecondColor
        FadedColor
    end

    methods
        function obj = InteractiveLollipopChart(T, varargin)
            if nargin < 1 || ~istable(T)
                error('InteractiveLollipopChart:InvalidInput', 'First input must be a table.');
            end
            obj.T = T;

            p = inputParser;
            addParameter(p, 'TeamVar', []);
            addParameter(p, 'TopNameVar', []);
            addParameter(p, 'TopValueVar', []);
            addParameter(p, 'SecondNameVar', []);
            addParameter(p, 'SecondValueVar', []);
            parse(p, varargin{:});
            nv = p.Results;

            % detect candidate columns
            [teamIdx, nameIdxs, numIdxs] = detectColumns(obj);

            obj.TeamVar = resolveColumnSpecifier(obj, nv.TeamVar, teamIdx);
            obj.TopNameVar = resolveColumnSpecifier(obj, nv.TopNameVar, nameIdxs(1));
            obj.SecondNameVar = resolveColumnSpecifier(obj, nv.SecondNameVar, nameIdxs(2));

            % default numeric columns selection
            if isempty(nv.TopValueVar) || isempty(nv.SecondValueVar)
                numSums = varfun(@(x) sum(double(x)), T(:, numIdxs), 'OutputFormat','uniform');
                [~, ord] = sort(numSums, 'descend');
                defaultTop = numIdxs(ord(1));
                defaultSecond = numIdxs(ord(2));
            else
                defaultTop = nv.TopValueVar;
                defaultSecond = nv.SecondValueVar;
            end
            obj.TopValueVar = resolveColumnSpecifier(obj, nv.TopValueVar, defaultTop);
            obj.SecondValueVar = resolveColumnSpecifier(obj, nv.SecondValueVar, defaultSecond);

            validateMappings(obj);

            obj.TopColor    = [0 0.4470 0.7410];
            obj.SecondColor = [0.8500 0.3250 0.0980];
            obj.FadedColor  = [0.85 0.85 0.85];

            createFigure(obj);
            drawChart(obj);
        end
    end

    methods (Access = private)
        function [teamIdx, nameIdxs, numIdxs] = detectColumns(obj)
            names = obj.T.Properties.VariableNames;
            n = numel(names);
            isTextLike = false(1,n);
            isNumericLike = false(1,n);
            for k = 1:n
                v = obj.T.(names{k});
                if isstring(v) || iscategorical(v) || iscellstr(v) || ischar(v)
                    isTextLike(k) = true;
                end
                if isnumeric(v) || islogical(v)
                    isNumericLike(k) = true;
                end
            end
            teamIdx = find(isTextLike,1);
            if isempty(teamIdx), teamIdx = 1; end

            nameCandidates = setdiff(find(isTextLike), teamIdx, 'stable');
            if numel(nameCandidates) < 2
                remaining = setdiff(1:n, teamIdx, 'stable');
                need = 2 - numel(nameCandidates);
                nameCandidates = [nameCandidates, remaining(1:need)];
            end
            nameIdxs = nameCandidates(1:2);

            numIdxs = find(isNumericLike);
            if numel(numIdxs) < 2
                error('InteractiveLollipopChart:NotEnoughNumeric', 'Need at least two numeric columns for values.');
            end
        end

        function idx = resolveColumnSpecifier(obj, spec, defaultIdx)
            if isempty(spec)
                idx = defaultIdx;
                return
            end
            if isnumeric(spec)
                idx = double(spec);
                return
            end
            specStr = string(spec);
            names = obj.T.Properties.VariableNames;
            tf = strcmp(names, specStr);
            if any(tf)
                idx = find(tf,1);
            else
                error('InteractiveLollipopChart:BadColumnName', 'Column "%s" not found.', specStr);
            end
        end

        function validateMappings(obj)
            nVars = width(obj.T);
            idxs = [obj.TeamVar, obj.TopNameVar, obj.SecondNameVar, obj.TopValueVar, obj.SecondValueVar];
            if any(idxs < 1) || any(idxs > nVars)
                error('InteractiveLollipopChart:BadIndex', 'One or more column indices out of range.');
            end
            vn = obj.T.Properties.VariableNames;
            if ~(isnumeric(obj.T.(vn{obj.TopValueVar})) || islogical(obj.T.(vn{obj.TopValueVar}))) || ...
                    ~(isnumeric(obj.T.(vn{obj.SecondValueVar})) || islogical(obj.T.(vn{obj.SecondValueVar})))
                error('InteractiveLollipopChart:ValueNotNumeric', 'Selected value columns must be numeric.');
            end
        end

        function createFigure(obj)
            obj.Fig = figure('Color', [0.95 0.95 0.95], ...
                'Name', 'Interactive Lollipop Chart', ...
                'NumberTitle', 'off', ...
                'Renderer', 'opengl');
            obj.Ax = axes('Parent', obj.Fig, ...
                'Color', [0.1 0.1 0.1], ...
                'XColor', 'k', ...
                'YColor', 'k', ...
                'FontSize', 11);
            hold(obj.Ax, 'on');
            grid(obj.Ax, 'on');
            obj.Ax.GridColor = [0.1 0.1 0.1];
            obj.Ax.GridAlpha = 1;
            obj.Ax.XTick = [];
        end

        function drawChart(obj)
            T = obj.T;
            n = height(T);

            % Selected value columns -> x positions
            xCols = [obj.TopValueVar, obj.SecondValueVar];
            x = 1:numel(xCols);     % typically [1 2]
            Y = double(T{:, xCols});% n x m
            m = size(Y,2);

            % row labels from RowNames (fallback to indices)
            if ~isempty(T.Properties.RowNames)
                rowLabels = string(T.Properties.RowNames);
            else
                rowLabels = string((1:n)');
            end

            % y limits and offset
            ymin = min(Y(:)); ymax = max(Y(:));
            yrange = max(1, ymax - ymin);
            margin = 0.06 * yrange;
            obj.Ax.YLim = [ymin - margin, ymax + margin];

            % Remove previous graphic children (if re-drawing)
            % Note: preserve axes and figure; delete only known handles if they exist
            if isgraphics(obj.Lines), delete(obj.Lines); obj.Lines = []; end
            if isgraphics(obj.ScatterTop), delete(obj.ScatterTop); obj.ScatterTop = []; end
            if isgraphics(obj.ScatterSecond), delete(obj.ScatterSecond); obj.ScatterSecond = []; end

            % For the common m == 2 case: create one line handle per row (2-by-n X/Y)
            if m == 2
                % m == 2: one vertical connector per row at x = row index
                % X coordinates: constant per row -> 2 x n
                X = repmat(1:n, 2, 1);          % 2 x n
                Ymat = [Y(:,1)'; Y(:,2)'];      % 2 x n
                obj.Lines = line(obj.Ax, X, Ymat, 'LineWidth', 1.6, 'HitTest', 'off');

                % per-line color: dominant value decides color
                topDominant = Y(:,1) >= Y(:,2);
                colMatrix = zeros(n,3);
                colMatrix(topDominant,:)  = repmat(obj.TopColor, sum(topDominant), 1);
                colMatrix(~topDominant,:) = repmat(obj.SecondColor, sum(~topDominant), 1);
                set(obj.Lines, {'Color'}, num2cell(colMatrix,2));

                % Place both markers at the same x so they sit exactly on the vertical line
                xs_center = (1:n)';            % x positions for rows
                markerSize = max(36, round(110 * min(1, 200/n)));

                % Use different marker symbols / sizes so both points remain distinguishable
                obj.ScatterTop = scatter(obj.Ax, xs_center, Y(:,1), markerSize, ...
                    'Marker','o', 'MarkerFaceColor', obj.TopColor, 'MarkerEdgeColor', 'k', ...
                    'LineWidth', 0.6, 'MarkerFaceAlpha', 1, 'HitTest', 'on');

                obj.ScatterSecond = scatter(obj.Ax, xs_center, Y(:,2), round(markerSize*0.7), ...
                    'Marker','s', 'MarkerFaceColor', obj.SecondColor, 'MarkerEdgeColor', 'k', ...
                    'LineWidth', 0.6, 'MarkerFaceAlpha', 1, 'HitTest', 'on');

                % use row labels on x axis
                xticks(obj.Ax, 1:n);
                xticklabels(obj.Ax, rowLabels);
                obj.Ax.XTickLabelRotation = 45;

                % place labels near markers (vertical offsets only)
                yOffset = max(0.02 * yrange, 0.2);
                text(obj.Ax, xs_center, Y(:,1) + yOffset, rowLabels, ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                    'Color', 'w', 'FontSize', 9, 'Interpreter', 'none', 'HitTest', 'off');
                text(obj.Ax, xs_center, Y(:,2) - yOffset, rowLabels, ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
                    'Color', 'w', 'FontSize', 9, 'Interpreter', 'none', 'HitTest', 'off');

                % datatips: show row and both values (for the scatters show their value)
                if isgraphics(obj.ScatterTop)
                    topRows = [dataTipTextRow('Row', cellstr(rowLabels)); dataTipTextRow('TopValue', num2cell(Y(:,1)))];
                    obj.ScatterTop.DataTipTemplate.DataTipRows = topRows;
                end
                if isgraphics(obj.ScatterSecond)
                    secondRows = [dataTipTextRow('Row', cellstr(rowLabels)); dataTipTextRow('SecondValue', num2cell(Y(:,2)))];
                    obj.ScatterSecond.DataTipTemplate.DataTipRows = secondRows;
                end

                % legend and toggling
                if isgraphics(obj.ScatterTop), obj.ScatterTop.DisplayName = 'Top'; end
                if isgraphics(obj.ScatterSecond), obj.ScatterSecond.DisplayName = 'Second'; end
                if isgraphics(obj.ScatterTop) && isgraphics(obj.ScatterSecond)
                    lgd = legend(obj.Ax, [obj.ScatterTop, obj.ScatterSecond], 'Location', 'best');
                    lgd.ItemHitFcn = @(~,event)obj.legendItemClick(event);
                end

                % X limits now based on rows
                obj.Ax.XLim = [0.5, n + 0.5];


            end

            % place row labels near points (vectorized)
            yOffset = max(0.02 * yrange, 0.2);
            if m == 2
                text(obj.Ax, repmat(x(1), n, 1), Y(:,1) + yOffset, rowLabels, ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                    'Color', 'w', 'FontSize', 9, 'Interpreter', 'none', 'HitTest', 'off');
                text(obj.Ax, repmat(x(2), n, 1), Y(:,2) - yOffset, rowLabels, ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
                    'Color', 'w', 'FontSize', 9, 'Interpreter', 'none', 'HitTest', 'off');
            else
                for col = 1:m
                    sign = 1 - 2*mod(col,2); % +1, -1 alternating
                    posY = Y(:,col) + sign * yOffset;
                    text(obj.Ax, repmat(x(col), n, 1), posY, rowLabels, ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                        'Color', 'w', 'FontSize', 9, 'Interpreter', 'none', 'HitTest', 'off');
                end
            end

            % datatips: show Row and Value for the main two scatters (if present)
            if isgraphics(obj.ScatterTop)
                topRows = [dataTipTextRow('Row', cellstr(rowLabels)); dataTipTextRow('Value', num2cell(Y(:,1)))];
                obj.ScatterTop.DataTipTemplate.DataTipRows = topRows;
            end
            if isgraphics(obj.ScatterSecond)
                secondRows = [dataTipTextRow('Row', cellstr(rowLabels)); dataTipTextRow('Value', num2cell(Y(:, min(2,m))))];
                obj.ScatterSecond.DataTipTemplate.DataTipRows = secondRows;
            end

            % legend and interactive toggling (for the two main series)
            if isgraphics(obj.ScatterTop), obj.ScatterTop.DisplayName = 'Top'; end
            if isgraphics(obj.ScatterSecond), obj.ScatterSecond.DisplayName = 'Second'; end
            if isgraphics(obj.ScatterTop) && isgraphics(obj.ScatterSecond)
                lgd = legend(obj.Ax, [obj.ScatterTop, obj.ScatterSecond], 'Location', 'best');
                lgd.ItemHitFcn = @(~,event)obj.legendItemClick(event);
            end

            % axis limits and appearance
            obj.Ax.YLim = [ymin - margin, ymax + margin];
            obj.Ax.XLim = [0.5, m + 0.5];
            obj.Ax.XTickLabelRotation = 45;
            ylabel(obj.Ax, 'Value');
        end

        function legendItemClick(obj, event)
            peer = event.Peer;
            if strcmp(peer.Visible, 'on')
                peer.Visible = 'off';
            else
                peer.Visible = 'on';
            end

            topVisible = isgraphics(obj.ScatterTop) && strcmp(obj.ScatterTop.Visible, 'on');
            secondVisible = isgraphics(obj.ScatterSecond) && strcmp(obj.ScatterSecond.Visible, 'on');

            nLines = numel(obj.Lines);
            if nLines == 0, return; end

            if topVisible && secondVisible
                % restore original colors based on YData
                ydataMat = reshape([obj.Lines.YData], 2, nLines)'; % n x 2 (m==2)
                topDominant = ydataMat(:,1) >= ydataMat(:,2);
                colMatrix = zeros(nLines,3);
                colMatrix(topDominant,:)  = repmat(obj.TopColor, sum(topDominant), 1);
                colMatrix(~topDominant,:) = repmat(obj.SecondColor, sum(~topDominant), 1);
            else
                colMatrix = repmat(obj.FadedColor, nLines, 1);
            end
            set(obj.Lines, {'Color'}, num2cell(colMatrix,2));

            if isgraphics(obj.ScatterTop)
                obj.ScatterTop.MarkerFaceAlpha = tern(topVisible, 1, 0.25);
            end
            if isgraphics(obj.ScatterSecond)
                obj.ScatterSecond.MarkerFaceAlpha = tern(secondVisible, 1, 0.25);
            end
        end
    end

    methods (Static, Access = private)
        function out = tern(cond, a, b)
            if cond, out = a; else out = b; end
        end
    end
end
